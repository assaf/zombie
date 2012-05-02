# For handling JavaScript, mostly improvements to JSDOM
CoffeeScript  = require("coffee-script")
HTML          = require("jsdom").dom.level3.html


# -- Patches to JSDOM --

# Support CoffeeScript.  Just because.
HTML.languageProcessors.coffeescript = (element, code, filename)->
  @javascript(element, CoffeeScript.compile(code), filename)


# If JSDOM encounters a JS error, it fires on the element.  We expect it to be
# fires on the Window.  We also want better stack traces.
HTML.languageProcessors.javascript = (element, code, filename)->
  if doc = element.ownerDocument
    window = doc.parentWindow
    try
      window._evaluate code, filename
    catch error
      unless error instanceof Error
        clone = new Error(error.message)
        clone.stack = error.stack
        error = clone
      raise element: element, location: filename, from: __filename, error: error


# HTML5 parser doesn't play well with JSDOM and inline scripts.
#
# Basically, DOMNodeInsertedIntoDocument event is captured when the script tag
# is added to the document, at which point it has the src attribute (external
# scripts) but no text content (inline scripts).  JSDOM will capture the event
# and try to execute an empty script.
#
# This code queues the script for processing and also lazily grabs the script's
# text content late enough that it's already set.
#
# Unfortunately, too late for some things to work properly -- basically once the
# HTML page has been processed -- so that needs to be fixed at some point.
HTML.Document.prototype._elementBuilders["script"] = (doc, tag)->
  script = new HTML.HTMLScriptElement(doc, tag)
  script.addEventListener "DOMNodeInsertedIntoDocument", (event)->
    unless @src
      src = @sourceLocation || {}
      filename = src.file || @_ownerDocument.URL

      if src
        filename += ":#{src.line}:#{src.col}"
      filename += "<script>"
      HTML.resourceLoader.enqueue(this, => @_eval(@text, filename))()
  return script


# -- Utility methods --

# Triggers an error event on the specified element.  Accepts:
# element - Element/document associated wit this error
# skip    - Filename of the caller (__filename), we use this to trim the stack trace
# scope   - Execution scope, e.g. "XHR", "Timeout"
# error   - Actual Error object
raise = ({ element, location, from, scope, error })->
  document = element.ownerDocument || element
  window = document.parentWindow
  message = if scope then "#{scope}: #{error.message}" else error.message
  location ||= document.location.href
  # Deconstruct the stack trace and strip the Zombie part of it
  # (anything leading to this file).  Add the document location at
  # the end.
  partial = []
  # "RangeError: Maximum call stack size exceeded" doesn't have a stack trace
  if error.stack
    for line in error.stack.split("\n")
      break if ~line.indexOf(from)
      partial.push line
  partial.push "    in #{location}"
  error.stack = partial.join("\n")

  event = document.createEvent("Event")
  event.initEvent "error", false, false
  event.message = error.message
  event.error = error
  window.browser.dispatchEvent window, event


module.exports = { raise }

