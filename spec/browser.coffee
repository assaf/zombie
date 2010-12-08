require.paths.unshift(__dirname)
JSDOM = require("jsdom")
URL = require("url")


# Fix not-too-smart URL resolving in JSDOM.
JSDOM.dom.level3.core.resourceLoader.resolve = (document, path)->
  path = URL.resolve(document.URL, path)
  path.replace(/^file:/, '').replace(/^([\/]+)/, "/")
JSDOM.dom.level3.core.resourceLoader.load = (element, href, callback)->
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
    @window = JSDOM.createWindow(JSDOM.dom.level3.html)
    # Attach history/location objects to window/document.
    require("history").apply(@window)
    # All asynchronous processing handled by event loop.
    @addEventLoop @window
    @window.XMLHttpRequest = -> {}
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
  # Adds an event loop to the window.
  addEventLoop: (window)->
    clock = 0
    timers = []
    lastHandle = 0
    queue = []
    # Implements window.setTimeout using event queue
    window.setTimeout = (fn, delay)->
      timer = 
        when: clock + delay
        fire: ->
          try
            if typeof fn == "function"
              fn.apply(window)
            else
              eval fn
          catch ex
            console.error "setTimeout", ex
          finally
            delete timers[handle]
      handle = ++lastHandle
      timers[handle] = timer
      handle
    # Implements window.setInterval using event queue
    window.setInterval = (fn, delay)->
      timer = 
        when: clock + delay
        fire: ->
          try
            if typeof fn == "function"
              fn.apply(window)
            else
              eval fn
          catch ex
            console.error "setTimeout", ex
            delete timers[handle]
          finally
            timer.when = clock + delay
      handle = ++lastHandle
      timers[handle] =
      handle
    # Implements window.clearTimeout using event queue
    window.clearTimeout = (handle)-> delete timers[handle]
    # Implements window.clearInterval using event queue
    window.clearInterval = (handle)-> delete timers[handle]
    # Process all pending events and timers in the queue
    window.process = (callback)->
      while queue.length > 0
        events = [].concat(queue)
        queue.clear
        for event in events
          console.log "firing", event
          event.apply(window)
        for timer in timers
          console.log "firing", timer
          timer.fire()
      callback(clock)

# Creates and returns new Browser
exports.new = -> new Browser
# Creates new browser, navigates to the specified URL and calls callback with
# err and window
exports.open = (url, callback)-> new Browser().open(url, callback)


###
vows.describe("Browser").addBatch({
  "open page":
    topic: ->
      browser = new Browser()
      server.ready => browser.open("http://localhost:3003/", @callback)
    "callback with document": (document)->
      assert.ok document, "no a document"
      assert.ok document instanceof JSDOM.dom.level3.html.HTMLDocument, "not an HTML document"
    "load document": (document)->
      content = document.outerHTML
      assert.ok /<body>Hello World<\/body>/.test(content), "HTML document without body"
    "load scripts": (document)->
      assert.ok jQuery = document.parentWindow.jQuery, "window.jQuery not available"
      assert.ok typeof jQuery.ajax == "function", "window.jQuery has no ajax function?"
    "run scripts": (document)->
      assert.equal document.title, "HAI"
    "run jquery.ready": (document)->
      $ = document.parentWindow.jQuery
      assert.equal $("body").data("foo"), "bar"


    "change location":
      topic: (document)->
        server.ready ->
          document.parentWindow.location = "http://localhost:3003/check"
          document.addEventListener "DOMContentLoaded", @callback
      "change document URL": (document)->
        console.log "hai"

  #teardown: -> server.close()
}).export(module);
###
