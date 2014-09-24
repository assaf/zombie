# Create an empty document.  Each window gets a new document.

Path                  = require("path")
JSDOM_PATH            = require.resolve("jsdom")

applyDocumentFeatures = require("#{JSDOM_PATH}/../jsdom/browser/documentfeatures").applyDocumentFeatures
browserAugmentation   = require("#{JSDOM_PATH}/../jsdom/browser/index").browserAugmentation
JSDOM                 = require("jsdom")
JSDOMSelectors        = require("#{JSDOM_PATH}/../jsdom/selectors/index")


# Creates an returns a new document attached to the window.
#
# browser - The browser
# window  - The window
# referer - Referring URL
module.exports = createDocument = (browser, window, referer)->
  features =
    MutationEvents:           "2.0"
    ProcessExternalResources: []
    FetchExternalResources:   []
    QuerySelector:            true

  # JSDOM's way of creating a document.
  jsdomBrowser = browserAugmentation(JSDOM.defaultLevel, parser: browser.htmlParser)
  # HTTP header Referer, but Document property referrer
  document = new jsdomBrowser.HTMLDocument(referrer: referer)
  JSDOMSelectors.applyQuerySelectorPrototype(JSDOM.defaultLevel)

  if browser.hasFeature("scripts", true)
    features.FetchExternalResources.push("script")
    features.ProcessExternalResources.push("script")
  if browser.hasFeature("css", false)
    features.FetchExternalResources.push("css")
    features.FetchExternalResources.push("link")
  if browser.hasFeature("img", false)
    features.FetchExternalResources.push("img")
  if browser.hasFeature("iframe", true)
    features.FetchExternalResources.push("iframe")
  applyDocumentFeatures(document, features)


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
