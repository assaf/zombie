# Fix things that JSDOM doesn't do quite right.


HTML          = require("jsdom").dom.level3.html


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
    browser.emit("link", anchor.href, anchor.target || "_self")



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
###
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
###
      

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

