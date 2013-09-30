# Fix things that JSDOM doesn't do quite right.


HTML  = require("jsdom").dom.level3.html
HTML5 = require("html5")



HTML.HTMLElement.prototype.__defineGetter__ "offsetLeft",   -> 0
HTML.HTMLElement.prototype.__defineGetter__ "offsetTop",    -> 0


# Script elements should always respond to a src attribute with something
HTML.HTMLScriptElement.prototype.__defineGetter__ "src", ->
  return @getAttribute('src') || ""

# These properties return empty string when attribute is not set.
HTML.HTMLElement.prototype.__defineGetter__ "id", ->
  return @getAttribute("id") || ""

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


# For some reason HTML5 uses elementBuilder instead of createElement
HTML5.TreeBuilder.prototype.createElement = (name, attributes, namespace)->
  el = this.document.createElement(name)
  el.namespace = namespace
  if(attributes)
    if(attributes.item)
      for i in [0...attributes.length]
        this.copyAttributeToElement(el, attributes.item(i))
    else
      for i in [0...attributes.length]
        this.copyAttributeToElement(el, attributes[i])
  return el

# Implement insertAdjacentHTML
HTML.HTMLElement.prototype.insertAdjacentHTML = (position, html)->
  container  = this.ownerDocument.createElementNS("http://www.w3.org/1999/xhtml", "_")
  parentNode = this.parentNode

  container.innerHTML = html

  switch position.toLowerCase()
    when "beforebegin"
      while (node = container.firstChild)
        parentNode.insertBefore(node, this)
    when "afterbegin"
      first_child = this.firstChild;
      while (node = container.lastChild)
        first_child = this.insertBefore(node, first_child);
    when "beforeend"
      while (node = container.firstChild)
        this.appendChild(node)
    when "afterend"
      next_sibling = this.nextSibling
      while (node = container.lastChild)
        next_sibling = parentNode.insertBefore(node, next_sibling)

