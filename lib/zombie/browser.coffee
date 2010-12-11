require.paths.unshift(__dirname)
fs = require("fs")
jsdom = require("jsdom")
require "./jsdom_patches"

# Use the browser to open up new windows and load documents.
#
# The browser maintains state for cookies and localStorage.
class Browser
  constructor: ->
    # Start out with an empty window
    @window = jsdom.createWindow(jsdom.dom.level3.html)
    @window.browser = this
    # Attach history/location objects to window/document.
    require("./history").apply(@window)
    # All asynchronous processing handled by event loop.
    require("./xhr").apply(@window)
    require("./eventloop").apply(@window)
    # Add Sizzle, default event handling, etc
    require("./document").apply(@window)

  # Loads document from the specified URL, and calls callback with null,
  # browser when done loading (corresponds to DOMContentLoaded event).
  #
  # If it fails to download, calls the callback with the error.
  open: (url, callback)->
    @window.location = url
    @window.addEventListener "error", (err)-> callback err
    @window.document.addEventListener "DOMContentLoaded", =>
      process.nextTick => callback null, this
    return
  cookies: {}
  localStorage: {}

  # Process all events from the queue. This method returns immediately, events
  # are processed in the background. When all events are exhausted, it calls
  # the callback with null, browser; if any event fails, it calls the callback
  # with the exception.
  #
  # With one argument, that argument is the callback. With two arguments, the
  # first argument is a terminator and the last argument is the callback. The
  # terminator is one of:
  # - null -- process all events
  # - number -- process that number of events
  # - function -- called after each event, stop processing when function
  #   returns false
  #
  # Events include timeout, interval and XHR onreadystatechange. DOM events
  # are handled synchronously.
  wait: (terminate, callback)->
    if !callback
      callback = terminate
      terminate = null
    @window.wait terminate, (err,window) =>
      callback err, this
    return

  # Returns elements that match the selector, either from the document or the
  # specified context element. Uses Sizzle.js.
  select: (selector, context)-> @window.select(selector, context)

  clickLink: (selector, callback)->
    for l in @select("a")
      if l.innerHTML == selector
        link = l
        break
    link ||= @select(selector)[0]
    if link
      evt = @window.document.createEvent("HTMLEvents")
      evt.initEvent "click", true, true
      link.dispatchEvent evt
      @wait callback if callback

# The main window's document. Only valid after opening a document
# (Browser.open).
Browser.prototype.__defineGetter__ "document", -> @window.document
# Location of the current document (same as window.location.href).
Browser.prototype.__defineGetter__ "location", -> @window.location.href
# Changes document location, loads new document if necessary (same as setting
# window.location).
Browser.prototype.__defineSetter__ "location", (url)-> @window.location = url
# Returns the HTML contents of the current document as a string.
Browser.prototype.__defineGetter__ "html", -> @window.document.outerHTML
# Returns the body Element of the current document.
Browser.prototype.__defineGetter__ "body", -> @window.Sizzle("body")[0]


exports.Browser = Browser
