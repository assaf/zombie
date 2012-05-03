# Fix things that JSDOM doesn't do quite right.
HTML = require("jsdom").dom.level3.html
URL = require("url")


###
HTML.HTMLElement.prototype.__defineGetter__ "offsetLeft",   -> 0
HTML.HTMLElement.prototype.__defineGetter__ "offsetTop",    -> 0
HTML.HTMLElement.prototype.__defineGetter__ "offsetWidth",  -> 100
HTML.HTMLElement.prototype.__defineGetter__ "offsetHeight", -> 100
###


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
        if /^javascript:/.test(href)
          url = URL.parse(href)
        else
          url = @resolve(element.window.parent.location, href)
          loaded = (response, filename)->
            callback response.body, URL.parse(response.url).pathname
          element.window.browser.resources.get url, @enqueue(element, loaded, url.pathname)
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
HTML.Document.prototype._elementBuilders["iframe"] = (doc, tag)->
  parent = doc.parentWindow

  iframe = new HTML.HTMLIFrameElement(doc, tag)
  iframe.window = parent.browser.open(parent: parent)
  iframe.window.parent = parent
  iframe._attributes.setNamedItem = (node)->
    HTML.NamedNodeMap.prototype.setNamedItem.call iframe._attributes, node
    if node._nodeName == "src" && node._nodeValue
      url = URL.resolve(parent.location.href, URL.parse(node._nodeValue))
      iframe.window.location.href = url
  return iframe


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


# textContent returns the textual content of nodes like text, comment,
# attribute, but when operating on elements, return only textual content of
# child text/element nodes.
HTML.Node.prototype.__defineGetter__ "textContent", ->
  if @nodeType == HTML.Node.TEXT_NODE || @nodeType == HTML.Node.COMMENT_NODE ||
     @nodeType == HTML.Node.ATTRIBUTE_NODE || @nodeType == HTML.Node.CDATA_SECTION_NODE
    return @nodeValue
  else if @nodeType == HTML.Node.ELEMENT_NODE || @nodeType == HTML.Node.DOCUMENT_FRAGMENT_NODE
    return @childNodes
      .filter((node)-> node.nodeType == HTML.Node.TEXT_NODE || node.nodeType == HTML.Node.ELEMENT_NODE ||
                       node.nodeType == HTML.Node.CDATA_SECTION_NODE)
      .map((node)-> node.textContent)
      .join("")
  else
    return null
      

HTML.NodeList.prototype.update = ->
    if @_element && @_version < @_element._version
      for i in [0.. @_length]
        delete this[i]
      if @_names
        for name in @_names
          delete this[name]
      nodes = @_snapshot = @_query()
      @_length = nodes.length
      @_names = []
      for i, node of nodes
        this[i] = node
        if name = node.name
          @_names.push name
          this[node.name] = node
      @_version = @_element._version
    return @_snapshot

