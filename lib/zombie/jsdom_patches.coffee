# Fix things that JSDOM doesn't do quite right.
HTML = require("jsdom").dom.level3.html
URL = require("url")


###
HTML.HTMLElement.prototype.__defineGetter__ "offsetLeft",   -> 0
HTML.HTMLElement.prototype.__defineGetter__ "offsetTop",    -> 0
HTML.HTMLElement.prototype.__defineGetter__ "offsetWidth",  -> 100
HTML.HTMLElement.prototype.__defineGetter__ "offsetHeight", -> 100
###


original = HTML.Element.prototype.setAttribute
HTML.Element.prototype.setAttribute = (name, value)->
  # JSDOM intercepts inline event handlers in a similar manner, but doesn't
  # manage window.event property or allow return false.
  if /^on.+/.test(name)
    wrapped = "if ((function() { " + value + " }).call(this,event) === false) event.preventDefault();"
    this[name] = (event)->
      # We're the window. This can happen because inline handlers on the body are
      # proxied to the window.
      window = if @run then this else @_ownerDocument.parentWindow
      # In-line event handlers rely on window.event
      try
        window.event = event
        # The handler code probably refers to functions declared in the
        # window context, so we need to call run().
        window.run(wrapped)
      finally
        window.event = null
    if @_ownerDocument
      attr = @._ownerDocument.createAttribute(name)
      attr.value = value
      @._attributes.setNamedItem(attr)
  else
    original.apply(this, arguments)


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
          window = element.contentWindow
          url = @resolve(window.parent.location, href)
          loaded = (response, filename)->
            callback response.body, URL.parse(response.url).pathname
          window.browser.resources.get url, @enqueue(element, loaded, url.pathname)
      else
        url = URL.parse(@resolve(document, href))
        if url.protocol == "file:"
          loaded = (data, filename)->
            callback.call this, data, filename
          file = "/#{url.hostname}#{url.pathname}"
          @readFile file, @enqueue(element, loaded, file)
        else
          loaded = (response, filename)->
            callback.call this, response.body, URL.parse(response.url).pathname
          window.browser.resources.get url, @enqueue(element, loaded, url.pathname)


# Support for iframes that load content when you set the src attribute.
HTML.Document.prototype._elementBuilders["iframe"] = (doc, tag)->
  parent = doc.window
  iframe = new HTML.HTMLIFrameElement(doc, tag)
  window = null
  Object.defineProperty iframe, "contentWindow", get: ->
    unless window
      # Need to bypass JSDOM's window/document creation and use ours
      window = parent.browser.open(name: iframe.name, parent: parent)
    return window
  Object.defineProperty iframe, "contentDocument", get: ->
    return window.document

  # This is also necessary to prevent JSDOM from messing with window/document
  iframe.setAttribute = (name, value)->
    if name == "src" && value
      # Point IFrame at new location and wait for it to load
      iframe.contentWindow.location = URL.resolve(parent.location, value)
      iframe.contentDocument.addEventListener "DOMContentLoaded", (event)->
        onload = parent.document.createEvent("HTMLEvents")
        onload.initEvent "load", false, false
        parent.browser._eventloop.dispatch iframe, onload
    else
      HTML.HTMLFrameElement.prototype.setAttribute.call(this, name, value)

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
      

# Form elements collection should allow retrieving individual element by its
# name, e.g. form.elements["username"] => <input name="username">
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

