# Support for iframes.


createHistory = require("./history")
HTML          = require("jsdom").dom.level3.html


# Support for iframes that load content when you set the src attribute.
frameInit = HTML.HTMLFrameElement._init
HTML.HTMLFrameElement._init = ->
  frameInit.call(this)
  frame = this

  parentWindow = frame.ownerDocument.parentWindow
  contentWindow = null

  Object.defineProperties frame,
    contentWindow:
      get: ->
        return contentWindow || create()
    contentDocument:
      get: ->
        return (contentWindow || create()).document

  # URL created on the fly, or when src attribute set
  create = (url)->
    # Change the focus from window to active.
    focus = (active)->
      contentWindow = active
    # Need to bypass JSDOM's window/document creation and use ours
    open = createHistory(parentWindow.browser, focus)
    contentWindow = open(name: frame.name, parent: parentWindow, url: url)
    return contentWindow

# This is also necessary to prevent JSDOM from messing with window/document
HTML.HTMLFrameElement.prototype.setAttribute = (name, value)->
  HTML.HTMLElement.prototype.setAttribute.call(this, name, value)

HTML.HTMLFrameElement.prototype._attrModified = (name, value, oldValue)->
  HTML.HTMLElement.prototype._attrModified.call(this, name, value, oldValue)
  if name == "name"
    @ownerDocument.parentWindow.__defineGetter__ value, =>
      return @contentWindow
  else if name == "src" && value
    # Point IFrame at new location and wait for it to load
    url = HTML.resourceLoader.resolve(@ownerDocument, value)
    @contentWindow.location = url
    onload = =>
      @contentWindow.removeEventListener("load", onload)
      onload = @ownerDocument.createEvent("HTMLEvents")
      onload.initEvent("load", true, false)
      @dispatchEvent(onload)
    @contentWindow.addEventListener("load", onload)
