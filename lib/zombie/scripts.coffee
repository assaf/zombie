# For handling JavaScript, mostly improvements to JSDOM
HTML  = require("jsdom").dom.level3.html
URL   = require("url")


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
  # This may be called without code, e.g. script element that has no body yet
  if code
    document = element.ownerDocument
    window = document.window
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
    element = event.target # Node being inserted
    # Let JSDOM deal with script tags with src attribute
    if element.tagName == "SCRIPT" && !element.src
      language = HTML.languageProcessors[element.language]
      if language
        # Only process supported languages

        executeInlineScript = (error, filename)->
          language(element, element.text, filename)
        # Make sure we execute in order, relative to all other scripts on the
        # page.  This also blocks document.close from firing DCL event until all
        # scripts are executed.
        executeInOrder = HTML.resourceLoader.enqueue(element, executeInlineScript, document.location.href)
        # There are two scenarios:
        # - script element added to existing document, we should evaluate it
        #   immediately
        # - inline script element parsed, when we get here, we still don't have
        #   the element contents, so we have to wait before we can read and
        #   execute it
        if document.readyState == "loading"
          process.nextTick(executeInOrder)
        else
          executeInOrder()
    return


# Fix resource loading to keep track of in-progress requests. Need this to wait
# for all resources (mainly JavaScript) to complete loading before terminating
# browser.wait.
HTML.resourceLoader.load = (element, href, callback)->
  document = element.ownerDocument
  window = document.parentWindow
  ownerImplementation = document.implementation
  tagName = element.tagName.toLowerCase()

  if ownerImplementation.hasFeature("FetchExternalResources", tagName)
    # This guarantees that all scripts are executed in order
    loaded = (response)->
      callback.call(element, response.body.toString(), url.pathname)
    url = HTML.resourceLoader.resolve(document, href)
    window._eventQueue.http "GET", url, { target: element }, @enqueue(element, loaded, url)


# Support onload, onclick etc inline event handlers
setAttribute = HTML.Element.prototype.setAttribute
HTML.Element.prototype.setAttribute = (name, value)->
  # JSDOM intercepts inline event handlers in a similar manner, but doesn't
  # manage window.event property or allow return false.
  if /^on.+/.test(name)
    wrapped = "if ((function() { " + value + " }).call(this,event) === false) event.preventDefault();"
    this[name] = (event)->
      # We're the window. This can happen because inline handlers on the body are
      # proxied to the window.
      if @run
        window = this
      else
        window = @_ownerDocument.parentWindow
      # In-line event handlers rely on window.event
      try
        window.event = event
        # The handler code probably refers to functions declared in the
        # window context, so we need to call run().
        window.run(wrapped)
      finally
        window.event = null
    if @_ownerDocument
      attr = @_ownerDocument.createAttribute(name)
      attr.value = value
      @_attributes.setNamedItem(attr)
  else
    setAttribute.apply(this, arguments)


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

  window._eventQueue.onerror(error)
  return


module.exports = { raise, addInlineScriptSupport }

