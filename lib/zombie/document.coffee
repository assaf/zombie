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


module.exports = createDocument
