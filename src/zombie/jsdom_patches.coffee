# Fix things that JSDOM doesn't do quite right.


DOM  = require("./dom")


DOM.HTMLDocument.prototype.__defineGetter__ "scripts",   ->
  return new DOM.HTMLCollection(this, => @querySelectorAll('script'))


# Default behavior for clicking on links: navigate to new URL if specified.
DOM.HTMLAnchorElement.prototype._eventDefaults =
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


# Attempt to load the image, this will trigger a 'load' event when succesful
# jsdom seemed to only queue the 'load' event
DOM.HTMLImageElement.prototype._attrModified = (name, value, oldVal) ->
  if (name == 'src')
    src = DOM.resourceLoader.resolve(this._ownerDocument, value)
    if this.src != src
      DOM.resourceLoader.load(this, value)


# Implement insertAdjacentHTML
DOM.HTMLElement.prototype.insertAdjacentHTML = (position, html)->
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
DOM.Node.prototype.contains = (otherNode) ->
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


# Support for opacity style property.
Object.defineProperty DOM.CSSStyleDeclaration.prototype, "opacity",
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
        this._setProperty("opacity", opacity)


# Wrap dispatchEvent to support _windowInScope and error handling.
jsdomDispatchEvent = DOM.EventTarget.prototype.dispatchEvent
DOM.EventTarget.prototype.dispatchEvent = (event)->
  # Could be node, window or document
  document = @_ownerDocument || @document || this
  window = document.parentWindow
  # Fail miserably on objects that don't have ownerDocument: nodes and XHR
  # request have those
  browser = window.browser
  browser.emit("event", event, this)

  try
    # The current window, postMessage and window.close need this
    [originalInScope, browser._windowInScope] = [browser._windowInScope, window]
    # Inline event handlers rely on window.event
    window.event = event
    return jsdomDispatchEvent.call(this, event)
  finally
    delete window.event
    browser._windowInScope = originalInScope


# Wrap raise to catch and propagate all errors to window
jsdomRaise = DOM.Document.prototype.raise
DOM.Document.prototype.raise = (type, message, data)->
  jsdomRaise.call(this, type, message, data)

  error = data && (data.exception || data.error)
  if error
    document = this
    window = document.parentWindow
    # Deconstruct the stack trace and strip the Zombie part of it
    # (anything leading to this file).  Add the document location at
    # the end.
    partial = []
    # "RangeError: Maximum call stack size exceeded" doesn't have a stack trace
    if error.stack
      for line in error.stack.split("\n")
        break if ~line.indexOf("contextify/lib/contextify.js")
        partial.push line
    partial.push "    in #{document.location.href}"
    error.stack = partial.join("\n")

    window._eventQueue.onerror(error)
  return


###
DOM.HTMLElement.prototype.__defineGetter__ "offsetLeft",   -> 0
DOM.HTMLElement.prototype.__defineGetter__ "offsetTop",    -> 0

# Changing style.height/width affects clientHeight/Weight and offsetHeight/Width
["height", "width"].forEach (prop)->
  client = "client#{prop[0].toUpperCase()}#{prop.slice(1)}"
  offset = "offset#{prop[0].toUpperCase()}#{prop.slice(1)}"
  Object.defineProperty DOM.HTMLElement.prototype, client,
    get: ->
      value = parseInt(this.style.getPropertyValue(prop), 10)
      if Number.isFinite(value)
        return value
      else
        return 100
  Object.defineProperty DOM.HTMLElement.prototype, offset,
    configurable: true
    get: ->
      return 0
###


