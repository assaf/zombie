# Fix things that JSDOM doesn't do quite right.
core = require("jsdom").dom.level3.core
URL = require("url")


# Event Handling
# --------------

# Add default event behavior (click link to navigate, click button to submit
# form, etc). We start by wrapping dispatchEvent so we can forward events to
# the element's _eventDefault function (only events that did not incur
# preventDefault).
dispatchEvent = core.HTMLElement.prototype.dispatchEvent
core.HTMLElement.prototype.dispatchEvent = (event)->
  outcome = dispatchEvent.call(this, event)
  event.target._eventDefault event unless event._preventDefault
  return outcome
core.HTMLElement.prototype._eventDefault = (event)->


# Scripts
# -------

# Need to use the same context for all the scripts we load in the same document,
# otherwise simple things won't work (e.g $.xhr)
core.languageProcessors =
  javascript: (element, code, filename)->
    document = element.ownerDocument
    window = document.parentWindow
    document._jsContext = process.binding("evals").Script.createContext(window)
    if window
      try
        process.binding("evals").Script.runInContext code, document._jsContext, filename
      catch ex
        console.error "Loading #{filename}", ex.stack


# Links/Resources
# ---------------

# Default behavior for clicking on links: navigate to new URL is specified.
core.HTMLAnchorElement.prototype._eventDefault = (event)->
  @ownerDocument.parentWindow.location = @href if event.type == "click" && @href

# Fix not-too-smart URL resolving in JSDOM.
core.resourceLoader.resolve = (document, path)->
  path = URL.resolve(document.URL, path)
  path.replace(/^file:/, '').replace(/^([\/]+)/, "/")
# Fix resource loading to keep track of in-progress requests. Need this to wait
# for all resources (mainly JavaScript) to complete loading before terminating
# browser.wait.
core.resourceLoader.load = (element, href, callback)->
  document = element.ownerDocument
  window = document.parentWindow
  ownerImplementation = document.implementation
  if ownerImplementation.hasFeature('FetchExternalResources', element.tagName.toLowerCase())
    window.request { url: href, method: "GET", headers: {} }, (done)=>
      url = URL.parse(@resolve(document, href))
      loaded = (data, filename)->
        done null, { status: 200, headers: {}, body: data.slice(0,100) }
        callback.call this, data, filename
      if url.hostname
        @download url, @enqueue(element, loaded, url.pathname)
      else
        file = @resolve(document, url.pathname)
        @readFile file, @enqueue(element, loaded, file)
