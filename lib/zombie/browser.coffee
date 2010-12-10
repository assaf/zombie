require.paths.unshift(__dirname)
jsdom = require("jsdom")
require "./jsdom_patches"
history = require("./history")
event_loop = require("./eventloop")
xhr = require("./xhr")

# Use the browser to open up new windows and load documents.
#
# The browser maintains state for cookies and localStorage.
class Browser
  constructor: ->
    # Start out with an empty window
    @window = jsdom.createWindow(jsdom.dom.level3.html)
    # Attach history/location objects to window/document.
    history.apply(@window)
    # All asynchronous processing handled by event loop.
    xhr.apply(@window)
    event_loop.apply(@window)
  # Loads document from the specified URL, and calls callback with the window
  # when the document is done loading (i.e ready). Callback receives error and
  # window.
  open: (url, callback)->
    @window.location = url
    @window.addEventListener "error", (err)-> callback err
    @window.document.addEventListener "DOMContentLoaded", =>
      process.nextTick => callback null, @window
    return # return nothing, useful in vow topic
  cookies: {}
  localStorage: {}

# Creates and returns new Browser
exports.new = -> new Browser
# Creates new browser, navigates to the specified URL and calls callback with
# err and window
exports.open = (url, callback)-> new Browser().open(url, callback)
