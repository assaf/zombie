core = require("jsdom").dom.level3.core
URL = require("url")

# Fix not-too-smart URL resolving in JSDOM.
core.resourceLoader.resolve = (document, path)->
  path = URL.resolve(document.URL, path)
  path.replace(/^file:/, '').replace(/^([\/]+)/, "/")
core.resourceLoader.load = (element, href, callback)->
  document = element.ownerDocument
  window = document.parentWindow
  ownerImplementation = document.implementation
  if ownerImplementation.hasFeature('FetchExternalResources', element.tagName.toLowerCase())
    url = URL.parse(@resolve(document, href))
    window.request (done)=>
      loaded = (data, filename)->
        done()
        callback.call this, data, filename
      if url.hostname
        @download url, @enqueue(element, loaded, url.pathname)
      else
        file = @resolve(document, url.pathname)
        @readFile file, @enqueue(element, loaded, file)
# Need to use the same context for all the scripts we load in the same document,
# otherwise simple things won't work (e.g $.xhr)
core.languageProcessors =
  javascript: (element, code, filename)->
    document = element.ownerDocument
    window = document.parentWindow
    document._jsContext = process.binding("evals").Script.createContext(window)
    if window
      try
        process.binding("evals").Script.runInContext code, document._jsContext, filename
      catch ex
        console.error "Loading #{filename}", ex.stack

# Implement form.reset
core.HTMLFormElement.prototype.reset = ->
  for field in @elements
    if field.nodeName == "SELECT"
      for option in field.options
        option.selected = option._defaultSelected
    else if field.nodeName == "INPUT" && field.type == "check" || field.type == "radio"
      field.checked = field._defaultChecked
    else if field.nodeName == "INPUT" || field.nodeName == "TEXTAREA"
      field.value = field._defaultValue
core.HTMLInputElement.prototype.click = ->
  if @type == "checkbox" || @type == "radio"
    @checked = !@checked
  # Instead of handling event directly we bubble it and let the default behavior kick in.
  event = @ownerDocument.createEvent("HTMLEvents")
  event.initEvent "click", true, true
  @dispatchEvent event
 
serializeFieldTypes = "email number password range search text url".split(" ")
# Implement form.submit
core.HTMLFormElement.prototype.submit = ->
  document = @ownerDocument
  params = {}
  for field in @elements
    continue if field.getAttribute("disabled")
    if field.nodeName == "SELECT" || field.nodeName == "TEXTAREA" || (field.nodeName == "INPUT" && serializeFieldTypes.indexOf(field.type) >= 0)
      params[field.getAttribute("name")] = field.value
    else if field.nodeName == "INPUT" && (field.type == "checkbox" || field.type == "radio")
      params[field.getAttribute("name")] = field.value if field.checked
  history = document.parentWindow.history
  history._submit @getAttribute("action"), @getAttribute("method"), params, @getAttribute("enctype")
