# For handling JavaScript, mostly improvements to JSDOM
DOM = require("./dom")
URL = require("url")


# -- Patches to JSDOM --

# If you're using CoffeeScript, you get client-side support.
try
  CoffeeScript = require("coffee-script")
  DOM.languageProcessors.coffeescript = (element, code, filename)->
    @javascript(element, CoffeeScript.compile(code), filename)
catch ex
  # Oh, well


# If JSDOM encounters a JS error, it fires on the element.  We expect it to be
# fires on the Window.  We also want better stack traces.
DOM.languageProcessors.javascript = (element, code, filename)->
  # Surpress JavaScript validation and execution
  window  = element.ownerDocument.window
  browser = window && window.top.browser
  if browser && !browser.runScripts
    return

  # This may be called without code, e.g. script element that has no body yet
  if code
    document = element.ownerDocument
    window = document.window
    try
      window._evaluate(code, filename)
    catch error
      unless error.hasOwnProperty("stack")
        cast = new Error(error.message || error.toString())
        cast.stack = error.stack
        error = cast
      document.raise("error", error.message, { exception: error })


# HTML5 parser doesn't play well with JSDOM so we need this trickey to sort of
# get script execution to work properly.
#
# Basically JSDOM listend for when the script tag is added to the DOM and
# attemps to evaluate at, but the script has no contents at that point in
# time.  This adds just enough delay for the inline script's content to be
# parsed and ready for processing.
DOM.HTMLScriptElement._init = ->
  @addEventListener "DOMNodeInsertedIntoDocument", ->
    if @src
      # Script has a src attribute, load external resource.
      DOM.resourceLoader.load(this, @src, @_eval)
    else
      if @id
        filename = "#{@ownerDocument.URL}:##{@id}"
      else
        filename = "#{@ownerDocument.URL}:script"
      # Execute inline script
      executeInlineScript = =>
        @_eval(@textContent, filename)
      # Queue to be executed in order with all other scripts
      executeInOrder = DOM.resourceLoader.enqueue(this, executeInlineScript, filename)
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
DOM.resourceLoader.load = (element, href, callback)->
  document      = element.ownerDocument
  window        = document.parentWindow
  tagName       = element.tagName.toLowerCase()
  loadResource  = document.implementation._hasFeature("FetchExternalResources", tagName)

  if loadResource
    # This guarantees that all scripts are executed in order
    loaded = (response)->
      callback.call(element, response.body.toString(), url.pathname)
    url = DOM.resourceLoader.resolve(document, href)
    window._eventQueue.http "GET", url, { target: element }, @enqueue(element, loaded, url)

