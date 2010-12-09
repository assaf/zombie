require.paths.unshift(__dirname)
jsdom = require("jsdom")
URL = require("url")

# Fix not-too-smart URL resolving in JSDOM.
jsdom.dom.level3.core.resourceLoader.resolve = (document, path)->
  path = URL.resolve(document.URL, path)
  path.replace(/^file:/, '').replace(/^([\/]+)/, "/")
jsdom.dom.level3.core.resourceLoader.load = (element, href, callback)->
  document = element.ownerDocument
  ownerImplementation = document.implementation
  if ownerImplementation.hasFeature('FetchExternalResources', element.tagName.toLowerCase())
    url = URL.parse(@resolve(document, href))
    if url.hostname
      @download url, @enqueue(element, callback, url.pathname)
    else
      file = @resolve(document, url.pathname)
      @readFile file, @enqueue(element, callback, file)



# Use the browser to open up new windows and load documents.
#
# The browser maintains state for cookies and localStorage.
class Browser
  constructor: ->
    # Start out with an empty window
    @window = jsdom.createWindow(jsdom.dom.level3.html)
    # Attach history/location objects to window/document.
    require("history").apply(@window)
    # All asynchronous processing handled by event loop.
    require("event_loop").apply(@window)
  # Loads document from the specified URL, and calls callback with the window
  # when the document is done loading (i.e ready).
  open: (url, callback)->
    # Hook into event  
    @window.location = url
    @window.document.addEventListener "DOMContentLoaded", =>
      process.nextTick => callback null, @window
    return # nothing
  cookies: {}
  localStorage: {}

# Creates and returns new Browser
exports.new = -> new Browser
# Creates new browser, navigates to the specified URL and calls callback with
# err and window
exports.open = (url, callback)-> new Browser().open(url, callback)
