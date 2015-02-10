assert                  = require("assert")
{ browserAugmentation } = require("jsdom/lib/jsdom/browser")
browserFeatures         = require("jsdom/lib/jsdom/browser/documentfeatures")
Window                  = require("jsdom/lib/jsdom/browser/Window")
DOM                     = require("./dom")
EventSource             = require("eventsource")
JSDOM                   = require("jsdom")
WebSocket               = require("ws")
XMLHttpRequest          = require("./xhr")
URL                     = require("url")


# browser   - The browser (required)
# history   - Window history (required)
# url       - URL of document to open (defaults to "about:blank")
# method    - HTTP method (defaults to "GET")
# encoding  - Request content type (forms use this)
# params    - Additional request parameters
# html      - Create document with this content instead of loading from URL
# name      - Window name
# referrer  - HTTP referer header
# parent    - Parent document (for frames)
# opener    - Opening window (for window.open)
# target    - Target window name (for form.submit)
module.exports = loadDocument = (args)->
  { browser } = args
  { history } = args
  assert(browser && browser.visit, "Missing parameter browser")
  assert(history && history.reload, "Missing parameter history")

  { url }     = args
  if url && browser.site
    site  = if /^(https?:|file:)/i.test(browser.site) then browser.site else "http://#{browser.site}"
    url   = URL.resolve(site, URL.parse(URL.format(url)))
  args.url   = url       || "about:blank"
  args.name  = args.name || ""

  document = createDocument(args)
  window   = document.parentWindow

  if args.html
    document.write(args.html)
    document.close()
    browser.emit("loaded", document)
    return document

  # Let's handle the specifics of each protocol
  { protocol, pathname } = URL.parse(args.url)
  switch protocol
    when "about:"
      document.close()
      browser.emit("loaded", document)
      return document

    when "javascript:"
      document.close()
      try
        window._evaluate(pathname, "javascript:")
        browser.emit("loaded", document)
      catch error
        browser.emit("error", error)
      return document

    when "http:", "https:", "file:"
      method = (args.method || "GET").toUpperCase()

      # Proceeed to load resource ...
      headers = args.headers || {}
      # HTTP header Referer, but Document property referrer
      headers.referer ||= args.referrer || browser.referrer || browser.referer || history.url || ""
      # Tell the browser we're looking for an HTML document
      headers.accept  ||= "text/html,*/*"
      # Forms require content type
      if method == "POST"
        headers["content-type"] = args.encoding || "application/x-www-form-urlencoded"

      window._eventQueue.http method, args.url, headers: headers, params: args.params, target: document, (error, response)->
        if response
          history.updateLocation(window, response.url)
          window._response    = response

        if error
          # 4xx/5xx we get an error with an HTTP response
          # Error in body of page helps with debugging
          message = (response && response.body) || error.message || error
          document.write "<html><body>#{message}</body></html>"
          document.close()
          return

        document.write(response.body)
        document.close()

        # Handle meta refresh.  Automatically reloads new location and counts
        # as a redirect.
        #
        # If you need to check the page before refresh takes place, use this:
        #   browser.wait({
        #     function: function() {
        #       return browser.query("meta[http-equiv='refresh']");
        #     }
        #   });
        refresh = document.querySelector("meta[http-equiv='refresh']")
        if refresh
          content = refresh.getAttribute("content")
          match   = content.match(/^\s*(\d+)(?:\s*;\s*url\s*=\s*(.*?))?\s*(?:;|$)/i)
          if match
            [nothing, refresh_timeout, refresh_url] = match
          else
            return
          refreshTimeout = parseInt(refresh_timeout, 10)
          refreshURL     = refresh_url || document.location.href
          if refreshTimeout >= 0
            window._eventQueue.enqueue ->
              # Count a meta-refresh in the redirects count.
              history.replace(refreshURL)
              # This results in a new window getting loaded
              newWindow = history.current.window
              newWindow.addEventListener "load", ->
                newWindow._response.redirects++
            return

        if document.documentElement
          browser.emit("loaded", document)
        else
          browser.emit("error", new Error("Could not parse document at #{response.url}"))

      return document

    else # but not any other protocol for now
      throw new Error("Cannot load resource #{url}, unsupported protocol")


# Creates an returns a new document attached to the window.
createDocument = ({ browser, url, html, name, parent, history, referrer, opener })->
  features =
    FetchExternalResources:   []
    ProcessExternalResources: []
    MutationEvents:           "2.0"
  if browser.hasFeature("scripts", true)
    features.FetchExternalResources.push("script")
    features.ProcessExternalResources.push("script")
  if browser.hasFeature("css", false)
    features.FetchExternalResources.push("css")
    features.FetchExternalResources.push("link")
  if browser.hasFeature("img", false)
    features.FetchExternalResources.push("img")
  if browser.hasFeature("iframe", true)
    features.FetchExternalResources.push("iframe")


  # Based on JSDOM.jsdom but skips the document.write
  # Calling document.write twice leads to strange results
  dom       = browserAugmentation(DOM, { parsingMode: "html" })
  document  = new dom.HTMLDocument({ url, referrer, parsingMode: "html" });
  browserFeatures.applyDocumentFeatures(document, features)
  window    = document.parentWindow
  setupDocument({ document, window, history, url })
  setupWindow({ browser, document, window, history, name, parent, opener })

  # Give event handler chance to register listeners.
  browser.emit("loading", document)

  return document


setupDocument = ({ window, document, history, url })->
  Object.defineProperty document, "window",
    value: window
    enumerable: true


setupWindow = ({ browser, window, document, name, parent, history, opener })->
  global = window.getGlobal()
  closed = false

  # Access to browser
  Object.defineProperty window, "browser",
    value: browser
    enumerable: true

  window.name = name


  # If this is an iframe within a parent window
  if parent
    window.parent = parent
    window.top    = parent.top
  else
    window.parent = global
    window.top    = global

  # If this was opened from another window
  window.opener   = opener

  window.console = browser.console

  # javaEnabled, present in browsers, not in spec Used by Google Analytics see
  # https://developer.mozilla.org/en/DOM/window.navigator.javaEnabled
  emptySet = []
  emptySet.item = ->
  emptySet.namedItem = ->
  window.navigator =
    appName:        "Zombie"
    cookieEnabled:  true
    javaEnabled:    ()-> false
    language:       browser.language
    mimeTypes:      emptySet
    noUI:           true
    platform:       process.platform
    plugins:        emptySet
    userAgent:      browser.userAgent
    vendor:         "Zombie Industries"
    version:        require("../../package.json").version

  # Add cookies, storage, alerts/confirm, XHR, WebSockets, JSON, Screen, etc
  Object.defineProperty window, "cookies",
    get: ->
      return browser.cookies.serialize(@location.hostname, @location.pathname)
  browser._storages.extend(window)
  browser._interact.extend(window)

  Object.defineProperties window,
    File:           { value: File }
    Event:          { value: DOM.Event }
    MouseEvent:     { value: DOM.MouseEvent }
    MutationEvent:  { value: DOM.MutationEvent }
    UIEvent:        { value: DOM.UIEvent }
  window.screen = new Screen()

  # Base-64 encoding/decoding
  window.atob = (string)->
    new Buffer(string, "base64").toString("utf8")
  window.btoa = (string)->
    new Buffer(string, "utf8").toString("base64")

  # Constructor for XHLHttpRequest
  window.XMLHttpRequest = ->
    return new XMLHttpRequest(window)

  # Web sockets
  window.WebSocket = (url, protocol)->
    url = DOM.resourceLoader.resolve(document, url)
    origin = "#{window.location.protocol}//#{window.location.host}"
    return new WebSocket(url, origin: origin, protocol: protocol)

  window.Image = (width, height)->
    img = new DOM.HTMLImageElement(window.document)
    img.width = width
    img.height = height
    return img

  # DataView: get from globals
  window.DataView = DataView

  window.resizeTo = (width, height)->
    window.outerWidth = window.innerWidth = width
    window.outerHeight = window.innerHeight = height
  window.resizeBy = (width, height)->
    window.resizeTo(window.outerWidth + width,  window.outerHeight + height)

  # Some libraries (e.g. Backbone) check that this property exists before
  # deciding to use onhashchange, so we need to set it to null.
  window.onhashchange = null

  # Help iframes talking with each other
  window.postMessage = (data, targetOrigin)->
    document = window.document
    # Create the event now, but dispatch asynchronously
    event = document.createEvent("MessageEvent")
    event.initEvent("message", false, false)
    event.data = data
    # Window A (source) calls B.postMessage, to determine A we need the
    # caller's window.

    # DDOPSON-2012-11-09 - _windowInScope.getGlobal() is used here so that for
    # website code executing inside the sandbox context, event.source ==
    # window. Even though the _windowInScope object is mapped to the sandboxed
    # version of the object returned by getGlobal, they are not the same
    # object ie, _windowInScope.foo == _windowInScope.getGlobal().foo, but
    # _windowInScope != _windowInScope.getGlobal()
    event.source = (browser._windowInScope || window).getGlobal()
    origin = event.source.location
    event.origin = URL.format(protocol: origin.protocol, host: origin.host)
    window.dispatchEvent(event)


  # -- JavaScript evaluation

  # Evaulate in context of window. This can be called with a script (String) or a function.
  window._evaluate = (code, filename)->
    try
      # The current window, postMessage and window.close need this
      [originalInScope, browser._windowInScope] = [browser._windowInScope, window]
      if typeof(code) == "string" || code instanceof String
        result = global.run(code, filename)
      else if code
        result = code.call(global)
      browser.emit("evaluated", code, result, filename)
      return result
    catch error
      error.filename ||= filename
      throw error
    finally
      browser._windowInScope = originalInScope


  # -- Event loop --

  eventQueue = browser.eventLoop.createEventQueue(window)
  Object.defineProperties window,
    _eventQueue:
      value: eventQueue
  window.setTimeout     = eventQueue.setTimeout.bind(eventQueue)
  window.clearTimeout   = eventQueue.clearTimeout.bind(eventQueue)
  window.setInterval    = eventQueue.setInterval.bind(eventQueue)
  window.clearInterval  = eventQueue.clearInterval.bind(eventQueue)
  window.setImmediate   = (fn)->
    eventQueue.setTimeout(fn, 0)
  window.clearImmediate = eventQueue.clearTimeout.bind(eventQueue)
  window.requestAnimationFrame  = eventQueue.setImmediate


  # Constructor for EventSource, URL is relative to document's.
  window.EventSource = (url)->
    url = DOM.resourceLoader.resolve(document, url)
    eventSource = new EventSource(url)
    eventQueue.addEventSource(eventSource)
    return eventSource

  # -- Opening and closing --

  # Open one window from another.
  window.open = (url, name, features)->
    url = url && DOM.resourceLoader.resolve(document, url)
    return browser.tabs.open(name: name, url: url, opener: window)

  # Indicates if window was closed
  Object.defineProperty window, "closed",
    get: -> closed
    enumerable: true

  # Destroy all the history (and all its windows), frames, and Contextify
  # global.
  window._destroy = ->
    # We call history.destroy which calls destroy on all windows, so need to
    # avoid infinite loop.
    if closed
      return

    closed = true
    # Close all frames first
    for frame in window.frames
      frame.close()
    # kill event queue, document and window.
    eventQueue.destroy()
    document.close()
    window.dispose()
    return

  # window.close actually closes the tab, and disposes of all windows in the history.
  # Also used to close iframe.
  window.close = ->
    if parent || closed
      return
    # Only opener window can close window; any code that's not running from
    # within a window's context can also close window.
    if browser._windowInScope == opener || browser._windowInScope == null
      # Only parent window gets the close event
      browser.emit("closed", window)
      window._destroy()
      history.destroy() # do this last to prevent infinite loop
    else
      browser.log("Scripts may not close windows that were not opened by script")
    return

  # -- Navigating --

  # Each window maintains its own view of history
  windowHistory =
    forward: ->
      windowHistory.go(1)
    back: ->
      windowHistory.go(-1)
    go: (amount)->
      browser.eventLoop.next ->
        history.go(amount)
    pushState: (args...)->
      history.pushState(args...)
    replaceState: (args...)->
      history.replaceState(args...)
    _submit:      history.submit.bind(history)
    dump:         history.dump.bind(history)
  Object.defineProperties windowHistory,
    length:
      get: -> return history.length
      enumerable: true
    state:
      get: -> return history.state
      enumerable: true

  # DOM History object
  window.history  = windowHistory
  # Actual history, see location getter/setter
  window._history = history


  # Form submission uses this
  window._submit = ({url, method, encoding, params, target, referrer })->
    url = DOM.resourceLoader.resolve(document, url)
    target ||= "_self"
    browser.emit("submit", url, target)
    # Figure out which history is going to handle this
    switch target
      when "_self"   # navigate same window
        submitTo = window
      when "_parent" # navigate parent window
        submitTo = window.parent
      when "_top"    # navigate top window
        submitTo = window.top
      else # open named window
        submitTo = browser.tabs.open(name: target)
    submitTo.history._submit(url: url, method: method, encoding: encoding, params: params)

  # JSDOM fires DCL event on document but not on window
  windowLoaded = (event)->
    document.removeEventListener("DOMContentLoaded", windowLoaded)
    window.dispatchEvent(event)
  document.addEventListener("DOMContentLoaded", windowLoaded)
  
  # Window is now open, next load the document.
  browser.emit("opened", window)


# File access, not implemented yet
class File


# Screen object provides access to screen dimensions
class Screen
  constructor: ->
    @top = @left = 0
    @width = 1280
    @height = 800

  @prototype.__defineGetter__ "availLeft", -> 0
  @prototype.__defineGetter__ "availTop", -> 0
  @prototype.__defineGetter__ "availWidth", -> 1280
  @prototype.__defineGetter__ "availHeight", -> 800
  @prototype.__defineGetter__ "colorDepth", -> 24
  @prototype.__defineGetter__ "pixelDepth", -> 24


# Change location, bypass JSDOM history
Window.prototype.__defineSetter__ "location", (url)->
  this._history.assign(url)

# Change location
DOM.Document.prototype.__defineSetter__ "location", (url)->
  this.parentWindow.location = url


