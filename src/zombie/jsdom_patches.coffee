# Fix things that JSDOM doesn't do quite right.


HTML  = require("jsdom").defaultLevel

HTML.HTMLDocument.prototype.__defineGetter__ "scripts",   ->
  return new HTML.HTMLCollection(this, => @querySelectorAll('script'))


HTML.HTMLElement.prototype.__defineGetter__ "offsetLeft",   -> 0
HTML.HTMLElement.prototype.__defineGetter__ "offsetTop",    -> 0


# Script elements should always respond to a src attribute with something
HTML.HTMLScriptElement.prototype.__defineGetter__ "src", ->
  return @getAttribute('src') || ""

# Meta elements should always respond to a name attribute
HTML.HTMLMetaElement.prototype.__defineGetter__ "name", ->
  return @getAttribute('name') || ""

# These properties return empty string when attribute is not set.
HTML.HTMLElement.prototype.__defineGetter__ "id", ->
  return @getAttribute("id") || ""

# These elements have a value property that must return empty string
for element in [HTML.HTMLInputElement, HTML.HTMLButtonElement, HTML.HTMLParamElement]
  element.prototype.__defineGetter__ "value", ->
    return @getAttribute("value") || ""

# Fix the retrieval of radio inputs for a radio group
# This backports the JsDom fix done in https://github.com/tmpvar/jsdom/pull/870
HTML.HTMLInputElement.prototype.__defineSetter__ "checked", (checked) ->
  @_initDefaultChecked();
  if checked
    @setAttribute 'checked', 'checked'

    if @type == 'radio'
      for  element in @_ownerDocument.getElementsByName(@name)
        if element != this && element.tagName == "INPUT" && element.type == "radio" && element.form == @form
          element.checked = false
  else
    @removeAttribute 'checked'


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
    opacity = this.getPropertyValue("opacity")
    if Number.isFinite(opacity)
      return opacity.toString()
    else
      return ""
  set: (opacity)->
    if opacity == null || opacity == undefined || opacity == ""
      this.removeProperty("opacity")
    else
      opacity = parseFloat(opacity)
      if isFinite(opacity)
        this.setProperty("opacity", opacity)


# Changing style.height/width affects clientHeight/Weight and offsetHeight/Width
["height", "width"].forEach (prop)->
  client = "client#{prop[0].toUpperCase()}#{prop.slice(1)}"
  offset = "offset#{prop[0].toUpperCase()}#{prop.slice(1)}"
  Object.defineProperty HTML.HTMLElement.prototype, client,
    get: ->
      value = parseInt(this.style.getPropertyValue(prop), 10)
      if Number.isFinite(value)
        return value
      else
        return 100
  Object.defineProperty HTML.HTMLElement.prototype, offset,
    get: ->
      return 0


# Attempt to load the image, this will trigger a 'load' event when succesful
# jsdom seemed to only queue the 'load' event
HTML.HTMLImageElement.prototype._attrModified = (name, value, oldVal) ->
  if (name == 'src' && value != oldVal)
    HTML.resourceLoader.load(this, value)

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

# Implement documentElement.contains
# e.g., if(document.body.contains(el)) { ... }
# See https://developer.mozilla.org/en-US/docs/DOM/Node.contains
HTML.Node.prototype.contains = (otherNode) ->
  # DDOPSON-2012-08-16 -- This implementation is stolen from Sizzle's
  # implementation of 'contains' (around line 1402).
  # We actually can't call Sizzle.contains directly:
  # * Because we define Node.contains, Sizzle will configure it's own
  #   "contains" method to call us. (it thinks we are a native browser
  #   implementation of "contains")
  # * Thus, if we called Sizzle.contains, it would form an infinite loop.
  #   Instead we use Sizzle's fallback implementation of "contains" based on
  #   "compareDocumentPosition".
  return !!(this.compareDocumentPosition(otherNode) & 16)

HTML.installStubCanvas = ->
  HTML.HTMLCanvasElement.prototype.getContext = ->
    imageSmoothingEnabled: ->
    webkitImageSmoothingEnabled: ->
    webkitBackingStorePixelRatio: ->
    currentPath: ->
    lineDashOffset: ->
    shadowBlurv: ->
    shadowOffsetY: ->
    shadowOffsetX: ->
    miterLimit: ->
    lineWidth: ->
    globalAlpha: ->
    canvas: ->
    save: ->
    restore: ->
    scale: ->
    rotate: ->
    translate: ->
    transform: ->
    setTransform: ->
    resetTransform: ->
    createLinearGradient: ->
    createRadialGradient: ->
    setLineDash: ->
    getLineDash: ->
    clearRect: ->
    fillRect: ->
    beginPath: ->
    fill: ->
    stroke: ->
    clip: ->
    isPointInPath: ->
    isPointInStroke: ->
    measureText: ->
    setAlpha: ->
    setCompositeOperation: ->
    setLineWidth: ->
    setLineCap: ->
    setLineJoin: ->
    setMiterLimit: ->
    clearShadow: ->
    fillText: ->
    strokeText: ->
    setStrokeColor: ->
    setFillColor: ->
    strokeRect: ->
    drawImage: ->
    drawImageFromRect: ->
    setShadow: ->
    putImageData: ->
    webkitPutImageDataHD: ->
    createPattern: ->
    createImageData: ->
    getImageData: ->
    webkitGetImageDataHD: ->
    getContextAttributes: ->
    closePath: ->
    moveTo: ->
    lineTo: ->
    quadraticCurveTo: ->
    bezierCurveTo: ->
    arcTo: ->
    rect: ->
    arc: ->
    ellipse: ->
