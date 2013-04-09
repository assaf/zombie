# Support for iframes.


createHistory = require("./history")
HTML          = require("jsdom").dom.level3.html


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
        iframe.dispatchEvent(onload)
      HTML.HTMLElement.prototype.setAttribute.call(this, name, value)
    else
      HTML.HTMLFrameElement.prototype.setAttribute.call(this, name, value)

  return iframe