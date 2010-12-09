core = require("jsdom").dom.level3.core
URL = require("url")

# Fix not-too-smart URL resolving in JSDOM.
core.resourceLoader.resolve = (document, path)->
  path = URL.resolve(document.URL, path)
  path.replace(/^file:/, '').replace(/^([\/]+)/, "/")
core.resourceLoader.load = (element, href, callback)->
  document = element.ownerDocument
  ownerImplementation = document.implementation
  if ownerImplementation.hasFeature('FetchExternalResources', element.tagName.toLowerCase())
    url = URL.parse(@resolve(document, href))
    if url.hostname
      @download url, @enqueue(element, callback, url.pathname)
    else
      file = @resolve(document, url.pathname)
      @readFile file, @enqueue(element, callback, file)
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
