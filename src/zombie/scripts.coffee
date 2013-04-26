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


# HTML5 parser doesn't play well with JSDOM so we need this trickey to sort of
# get script execution to work properly.
#
# Basically JSDOM listend for when the script tag is added to the DOM and
# attemps to evaluate at, but the script has no contents at that point in
# time.  This adds just enough delay for the inline script's content to be
# parsed and ready for processing.
HTML.HTMLScriptElement._init = ->
  @addEventListener "DOMNodeInsertedIntoDocument", ->
    if @src
      # Script has a src attribute, load external resource.
      HTML.resourceLoader.load(this, @src, @_eval)
    else
      if @id
        filename = "#{@ownerDocument.URL}:##{id}"
      else
        filename = "#{@ownerDocument.URL}:script"
      # Execute inline script
      executeInlineScript = =>
        @_eval(@textContent, filename)
      # Queue to be executed in order with all other scripts
      executeInOrder = HTML.resourceLoader.enqueue(this, executeInlineScript, filename)
      # There are two scenarios:
      # - script element added to existing document, we should evaluate it
      #   immediately
      # - inline script element parsed, when we get here, we still don't have
      #   the element contents, so we have to wait before we can read and
      #   execute it
      if @ownerDocument.readyState == "loading"
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


# Triggers an error event on the specified element.  Accepts:
# element  - Element/document associated with this error
# location - Location of this error
# scope    - Execution scope, e.g. "XHR", "Timeout"
# error    - Actual Error object
module.exports = raise = ({ element, location, scope, error })->
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
