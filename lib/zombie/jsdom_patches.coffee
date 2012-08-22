# Fix things that JSDOM doesn't do quite right.
Path          = require("path")
sizzle = Path.resolve(require.resolve("jsdom"), "../jsdom/selectors/sizzle")
createSizzle  = require(sizzle)
HTML          = require("jsdom").dom.level3.html
URL           = require("url")


HTML.HTMLElement.prototype.__defineGetter__ "offsetLeft",   -> 0
HTML.HTMLElement.prototype.__defineGetter__ "offsetTop",    -> 0


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


# Essentially all web browsers (Firefox, Internet Explorer, recent versions of
# Opera, Safari, Konqueror, and iCab, as a non-exhaustive list) return null when
# the specified attribute does not exist on the specified element. The DOM
# specification says that the correct return value in this case is actually the
# empty string, and some DOM implementations implement this behavior.
# -- https://developer.mozilla.org/en/DOM/element.getAttribute#Notes
HTML.Element.prototype.getAttribute = (name)->
  attribute = @_attributes.getNamedItem(name)
  return attribute?.value || null

# These two patches are required by the above fix.
HTML.HTMLAnchorElement.prototype.__defineGetter__ "href", ->
  return HTML.resourceLoader.resolve(@_ownerDocument, @getAttribute('href') || "")
HTML.HTMLLinkElement.prototype.__defineGetter__ "href", ->
  return HTML.resourceLoader.resolve(@_ownerDocument, @getAttribute('href') || "")

# These properties return empty string when attribute is not set.
HTML.HTMLElement.prototype.__defineGetter__ "id", ->
  return @getAttribute("id") || ""
# These elements have a name property that must return empty string
for element in [HTML.HTMLFormElement, HTML.HTMLMenuElement, HTML.HTMLSelectElement,
                HTML.HTMLInputElement, HTML.HTMLTextAreaElement, HTML.HTMLButtonElement,
                HTML.HTMLAnchorElement, HTML.HTMLImageElement, HTML.HTMLObjectElement,
                HTML.HTMLParamElement, HTML.HTMLAppletElement, HTML.HTMLMapElement,
                HTML.HTMLFrameElement, HTML.HTMLIFrameElement]
  element.prototype.__defineGetter__ "name", ->
    return @getAttribute("name") || ""
# These elements have a value property that must return empty string
for element in [HTML.HTMLInputElement, HTML.HTMLButtonElement, HTML.HTMLParamElement]
  element.prototype.__defineGetter__ "value", ->
    return @getAttribute("value") || ""


# Default behavior for clicking on links: navigate to new URL if specified.
HTML.HTMLAnchorElement.prototype._eventDefaults =
  click: (event)->
    anchor = event.target
    return unless anchor.href

    window = anchor.ownerDocument.parentWindow
    browser = window.browser
    # Decide which window to open this link in
    switch anchor.target || "_self"
      when "_self" # open in same window
        window = window
      when "_parent" # pick parent window
        window = window.parent
      when "_top" # pick top window
        window = window.top
      else
        # If this is a named window, open in existing window or create a new
        # one.  This also works for _blank (always open new one)
        window = browser.windows.get(anchor.target) ||
                 browser.open(name: anchor.target)
    # Make sure to select window as the current one
    browser.windows.select(window)
    window.location = anchor.href


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
      iframe.contentWindow.addEventListener "load", (event)->
        onload = parent.document.createEvent("HTMLEvents")
        onload.initEvent "load", false, false
        parent.browser._eventloop.dispatch iframe, onload
      HTML.HTMLElement.prototype.setAttribute.call(this, name, value)
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

# Changing style.height/width affects clientHeight/Weight and offsetHeight/Width
["height", "width"].forEach (prop)->
  internal = "_#{prop}"
  client = "client#{prop[0].toUpperCase()}#{prop.slice(1)}"
  offset = "offset#{prop[0].toUpperCase()}#{prop.slice(1)}"
  Object.defineProperty HTML.CSSStyleDeclaration.prototype, prop,
    get: ->
      return this[internal] || ""
    set: (value)->
      if /^\d+px$/.test(value)
        this[internal] = value
      else if !value
        delete this[internal]
  Object.defineProperty HTML.HTMLElement.prototype, client,
    get: ->
      return parseInt(this[internal] || 100)
  Object.defineProperty HTML.HTMLElement.prototype, offset,
    get: ->
      return parseInt(this[internal] || 100)


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

# Implement documentElement.contains
# e.g., if(document.body.contains(el)) { ... }
# See https://developer.mozilla.org/en-US/docs/DOM/Node.contains
HTML.Node.prototype.contains = (otherNode) ->
  # DDOPSON-2012-08-16 -- This implementation is stolen from Sizzle's implementation of 'contains' (around line 1402).
  # We actually can't call Sizzle.contains directly: 
  # * Because we define Node.contains, Sizzle will configure it's own "contains" method to call us. (it thinks we are a native browser implementation of "contains")
  # * Thus, if we called Sizzle.contains, it would form an infinite loop.  Instead we use Sizzle's fallback implementation of "contains" based on "compareDocumentPosition".
  return !!(this.compareDocumentPosition(otherNode) & 16)


HTML.HTMLDocument.prototype.querySelector = (selector)->
  @_sizzle ||= createSizzle(this)
  return @_sizzle(selector, this)[0]
HTML.HTMLDocument.prototype.querySelectorAll = (selector)->
  @_sizzle ||= createSizzle(this)
  return new HTML.NodeList(@_sizzle(selector, this))

# True if element is child of context node or any of its children.
descendantOf = (element, context)->
  parent = element.parentNode
  if parent
    return parent == context || descendantOf(parent, context)
  else
    return false

# Here comes the tricky part:
#   getDocumentById("foo").querySelectorAll("#foo div")
# should magically find the div descendant(s) of #foo, although
# querySelectorAll can never "see" itself.
descendants = (element, selector)->
  document = element.ownerDocument
  document._sizzle ||= createSizzle(document)
  unless element.parentNode
    parent = element.ownerDocument.createElement("div")
    parent.appendChild(element)
    element = parent
  return document._sizzle(selector, element.parentNode || element)
    .filter((node) -> descendantOf(node, element))


HTML.Element.prototype.querySelector = (selector)->
  return descendants(this, selector)[0]
HTML.Element.prototype.querySelectorAll = (selector)->
  return new HTML.NodeList(descendants(this, selector))
