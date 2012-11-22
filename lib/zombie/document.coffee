# Create an empty document.  Each window gets a new document.

JSDOM   = require("jsdom")
Scripts = require("./scripts")
HTML     = JSDOM.dom.level3.html


# Creates an returns a new document attached to the window.
#
# browser - The browser
# window  - The window
# referer - Referring URL
createDocument = (browser, window, referer)->
  features =
    MutationEvents:           "2.0"
    ProcessExternalResources: []
    FetchExternalResources:   []
    QuerySelector:            true

  # JSDOM's way of creating a document.
  jsdomBrowser = JSDOM.browserAugmentation(HTML, parser: browser.htmlParser)
  # HTTP header Referer, but Document property referrer
  document = new jsdomBrowser.HTMLDocument(referrer: referer)

  if browser.hasFeature("scripts", true)
    features.ProcessExternalResources.push("script")
    features.FetchExternalResources.push("script")
    # Add support for running in-line scripts
    Scripts.addInlineScriptSupport(document)

  if browser.hasFeature("css", false)
    features.FetchExternalResources.push("css")
  if browser.hasFeature("iframe", true)
    features.FetchExternalResources.push("iframe")
  JSDOM.applyDocumentFeatures(document, features)


  # Tie document and window together
  Object.defineProperty document, "window",
    value: window
  Object.defineProperty document, "parentWindow",
    value: window.parent # JSDOM property?

  Object.defineProperty document, "location",
    get: ->
      return window.location
    set: (url)->
      window.location = url
  Object.defineProperty document, "URL",
    get: ->
      return window.location.href

  return document


# The element in focus.
HTML.HTMLDocument.prototype.__defineGetter__ "activeElement", ->
  @_inFocus || @body

# Change the current element in focus (or null for blur)
setFocus = (document, element)->
  unless element == document._inFocus
    if document._inFocus
      onblur = document.createEvent("HTMLEvents")
      onblur.initEvent "blur", false, false
      document._inFocus.dispatchEvent(onblur)
    if element
      onfocus = document.createEvent("HTMLEvents")
      onfocus.initEvent("focus", false, false)
      element.dispatchEvent(onfocus)
    document._inFocus = element

# Focus/blur exist on all elements but do nothing if not an input
HTML.Element.prototype.focus = ->
HTML.Element.prototype.blur = ->

for element in [HTML.HTMLInputElement, HTML.HTMLSelectElement, HTML.HTMLTextAreaElement, HTML.HTMLButtonElement, HTML.HTMLAnchorElement]
  element.prototype.focus = ->
    setFocus(@ownerDocument, this)
  element.prototype.blur = ->
    if @ownerDocument.activeElement == this
      setFocus(@ownerDocument, null)


# Capture the autofocus element and use it to change focus
setAttribute = HTML.HTMLElement.prototype.setAttribute
HTML.HTMLElement.prototype.setAttribute = (name, value)->
  setAttribute.call(this, name, value)
  if name == "autofocus" && ~["INPUT", "SELECT", "TEXTAREA", "BUTTON", "ANCHOR"].indexOf(@tagName)
    @ownerDocument._inFocus = this


module.exports = createDocument

