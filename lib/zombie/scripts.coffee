# For handling JavaScript, mostly improvements to JSDOM
HTML  = require("jsdom").dom.level3.html


# -- Patches to JSDOM --

# If you're using CoffeeScript, you get client-side support.
try
  CoffeeScript = require("coffee-script")
  HTML.languageProcessors.coffeescript = (element, code, filename)->
    @javascript(element, CoffeeScript.compile(code), filename)
catch ex
  # Oh, well


# If JSDOM encounters a JS error, it fires on the element.  We expect it to be
# fires on the Window.  We also want better stack traces.
HTML.languageProcessors.javascript = (element, code, filename)->
  if doc = element.ownerDocument
    window = doc.parentWindow
    try
      window._evaluate(code, filename)
    catch error
      unless error instanceof Error
        cast = new Error(error.message)
        cast.stack = error.stack
        error = cast
      raise element: element, location: filename, from: __filename, error: error


# HTML5 parser doesn't play well with JSDOM and inline scripts.  This methods
# adds proper inline script support.
#
# Basically, JSDOM listens on the script tag, waiting for
# DOMNodeInsertedIntoDocument, at which point the script tag may have a src
# attribute (external) but no text content (internal), so in the later case it
# attempts to execute an empty string.
#
# OTOH when we listen to DOMNodeInserted event on the document, the script tag
# includes its full text content and we're able to evaluate it correctly.
addInlineScriptSupport = (document)->
  # Basically we're going to listen to new script tags as they are inserted into
  # the DOM and then queue them to be processed.  JSDOM does the same, but
  # listens on the script element itself, and someone the event it captures
  # doesn't have any of the script contents.
  document.addEventListener "DOMNodeInserted", (event)->
    node = event.target # Node being inserted
    return unless node.tagName == "SCRIPT"
    # Process scripts in order.
    HTML.resourceLoader.enqueue(node, ->
      code = node.text
      # Only process supported languages
      language = HTML.languageProcessors[node.language]
      if code && language
        # Queue so inline scripts execute in order with external scripts
        language(this, code, document.location.href)
    )()
    return


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
      break if ~line.indexOf("contextify/lib/contextify.js")
      partial.push line
  partial.push "    in #{location}"
  error.stack = partial.join("\n")

  event = document.createEvent("Event")
  event.initEvent "error", false, false
  event.message = error.message
  event.error = error
  window.dispatchEvent event
  return


module.exports = { raise, addInlineScriptSupport }

