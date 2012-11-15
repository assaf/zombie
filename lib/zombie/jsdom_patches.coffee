# Fix things that JSDOM doesn't do quite right.
createHistory = require("./history")
Path          = require("path")
sizzle        = Path.resolve(require.resolve("jsdom"), "../jsdom/selectors/sizzle")
createSizzle  = require(sizzle)
HTML          = require("jsdom").dom.level3.html
URL           = require("url")


HTML.HTMLElement.prototype.__defineGetter__ "offsetLeft",   -> 0
HTML.HTMLElement.prototype.__defineGetter__ "offsetTop",    -> 0


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

    window = anchor.ownerDocument.window
    browser = window.browser
    # Decide which window to open this link in
    switch anchor.target || "_self"
      when "_self"   # navigate same window
        window.location = anchor.href
      when "_parent" # navigate parent window
        window.parent.location = anchor.href
      when "_top"    # navigate top window
        window.top.location = anchor.href
      else # open named window
        browser.tabs.open(name: anchor.target, url: anchor.href)



# Support for iframes that load content when you set the src attribute.
HTML.Document.prototype._elementBuilders["iframe"] = (document, tag)->
  parent = document.window
  iframe = new HTML.HTMLIFrameElement(document, tag)

  Object.defineProperties iframe,
    contentWindow:
      get: ->
        return window || create()
    contentDocument:
      get: ->
        return (window || create()).document

  # URL created on the fly, or when src attribute set
  window = null
  create = (url)->
    # Change the focus from window to active.
    focus = (active)->
      window = active
    # Need to bypass JSDOM's window/document creation and use ours
    open = createHistory(parent.browser, focus)
    window = open(name: iframe.name, parent: parent, url: url)

  # This is also necessary to prevent JSDOM from messing with window/document
  iframe.setAttribute = (name, value)->
    if name == "src" && value
      # Point IFrame at new location and wait for it to load
      url = HTML.resourceLoader.resolve(parent.document, value)
      if window
        window.location = url
      else
        create(url)
      window.addEventListener "load", ->
        onload = document.createEvent("HTMLEvents")
        onload.initEvent("load", true, false)
        parent._dispatchEvent(iframe, onload, true)
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

