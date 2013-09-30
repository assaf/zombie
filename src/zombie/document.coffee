# Create an empty document.  Each window gets a new document.

JSDOM           = require("jsdom")
HTML            = JSDOM.dom.level3.html
Path            = require("path")
JSDOMSelectors  = require(Path.resolve(require.resolve("jsdom"), "../jsdom/selectors/index"))


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
  jsdomBrowser = JSDOM.browserAugmentation(HTML, parser: browser.htmlParser)
  # HTTP header Referer, but Document property referrer
  document = new jsdomBrowser.HTMLDocument(referrer: referer)
  JSDOMSelectors.applyQuerySelectorPrototype(HTML)

  if browser.hasFeature("scripts", true)
    features.ProcessExternalResources.push("script")
    features.FetchExternalResources.push("script")

  if browser.hasFeature("css", false)
    features.FetchExternalResources.push("css")
    features.FetchExternalResources.push("link")
  if browser.hasFeature("img", false)
    features.FetchExternalResources.push("img")
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
