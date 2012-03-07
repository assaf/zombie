# Fix things that JSDOM doesn't do quite right.
HTML = require("jsdom").dom.level3.html
URL = require("url")
{ raise } = require("./helpers")


HTML.HTMLElement.prototype.__defineGetter__ "offsetLeft",   -> 0
HTML.HTMLElement.prototype.__defineGetter__ "offsetTop",    -> 0
HTML.HTMLElement.prototype.__defineGetter__ "offsetWidth",  -> 100
HTML.HTMLElement.prototype.__defineGetter__ "offsetHeight", -> 100


# Default behavior for clicking on links: navigate to new URL is specified.
HTML.HTMLAnchorElement.prototype._eventDefaults =
  click: (event)->
    anchor = event.target
    anchor.ownerDocument.parentWindow.location = anchor.href if anchor.href


# Fix resource loading to keep track of in-progress requests. Need this to wait
# for all resources (mainly JavaScript) to complete loading before terminating
# browser.wait.
HTML.resourceLoader.load = (element, href, callback)->
  document = element.ownerDocument
  window = document.parentWindow
  ownerImplementation = document.implementation
  tagName = element.tagName.toLowerCase()

  if ownerImplementation.hasFeature('FetchExternalResources', tagName)
    switch tagName
      when "iframe"
        element.window.location = URL.resolve(element.window.parent.location, href)
      else
        url = URL.parse(@resolve(document, href))
        if url.hostname
          loaded = (response, filename)->
            callback.call this, response.body, URL.parse(response.url).pathname
          window.browser.resources.get url, @enqueue(element, loaded, url.pathname)
        else
          loaded = (data, filename)->
            callback.call this, data, filename
          file = @resolve(document, url.pathname)
          @readFile file, @enqueue(element, loaded, file)


# Support for iframes that load content when you set the src attribute.
HTML.Document.prototype._elementBuilders["iframe"] = (doc, s)->
  parent = doc.parentWindow

  iframe = new HTML.HTMLIFrameElement(doc, s)
  iframe.window = parent.browser.open(parent: parent)
  iframe.window.parent = parent
  iframe._attributes.setNamedItem = (node)->
    HTML.NamedNodeMap.prototype.setNamedItem.call iframe._attributes, node
    if node._nodeName == "src" && node._nodeValue
      url = URL.resolve(parent.location.href, URL.parse(node._nodeValue))
      iframe.window.location.href = url
  return iframe


# If JSDOM encounters a JS error, it fires on the element.  We expect it to be
# fires on the Window.  We also want better stack traces.
HTML.languageProcessors.javascript = (element, code, filename)->
  if doc = element.ownerDocument
    window = doc.parentWindow
    try
      window._evaluate code, filename
    catch error
      raise element: element, location: filename, from: __filename, error: error


# Support for opacity style property.
Object.defineProperty HTML.CSSStyleDeclaration.prototype, "opacity",
  get: ->
    return @_opacity || ""
  set: (opacity)->
    if opacity
      opacity = parseFloat(opacity)
      unless isNaN(opacity)
        @_opacity = opacity.toString()
    else
      delete @_opacity

