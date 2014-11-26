# Exports single function for creating a new Window.

Path            = require("path")
JSDOM_PATH      = require.resolve("jsdom")
 
createDocument  = require("./document")
EventSource     = require("eventsource")
History         = require("./history")
JSDOM           = require("jsdom")
WebSocket       = require("ws")
URL             = require("url")
XMLHttpRequest  = require("./xhr")
createWindow    = require("#{JSDOM_PATH}/../jsdom/browser/index").createWindow
XPath           = require("#{JSDOM_PATH}/../jsdom/level3/xpath")


Events      = JSDOM.level(3, 'events')
HTML        = JSDOM.defaultLevel


# Create and return a new Window.
#
# Parameters
# browser   - Browser that owns this window
# params    - Data to submit (used by forms)
# encoding  - Encoding MIME type (used by forms)
# history   - This window shares history with other windows
# method    - HTTP method (used by forms)
# name      - Window name (optional)
# opener    - Opening window (window.open call)
# parent    - Parent window (for frames)
# referer   - Use this as referer
# url       - Set document location to this URL upon opening
module.exports = ({ browser, params, encoding, history, method, name, opener, parent, referer, url })->
  name  ||= ""
  url   ||= "about:blank"

  window = createWindow(HTML)
  global = window.getGlobal()
  # window`s have a closed property defaulting to false
  closed = false

  # Access to browser
  Object.defineProperty window, "browser",
    value: browser
    enumerable: true

  # -- Document --

  # Each window has its own document
  document = createDocument(browser, window, referer || history.url)
  Object.defineProperty window, "document",
    value: document
    enumerable: true


  # -- DOM Window features

  Object.defineProperty window, "name",
    value: name
    enumerable: true
  # If this is an iframe within a parent window
  if parent
    Object.defineProperty window, "parent",
      value: parent
      enumerable: true
    Object.defineProperty window, "top",
      value: parent.top
      enumerable: true
  else
    Object.defineProperty window, "parent",
      value: global
      enumerable: true
    Object.defineProperty window, "top",
      value: global
      enumerable: true

  # If this was opened from another window
  Object.defineProperty window, "opener",
    value: opener && opener
    enumerable: true

  # Window title is same as document title
  Object.defineProperty window, "title",
    get: ->
      return document.title
    set: (title)->
      document.title = title
    enumerable: true

  Object.defineProperty window, "console",
    value: browser.console
    enumerable: true

  Object.defineProperty window, "requestAnimationFrame",
    get: -> window.setImmediate

  # javaEnabled, present in browsers, not in spec Used by Google Analytics see
  # https://developer.mozilla.org/en/DOM/window.navigator.javaEnabled
  Object.defineProperties window.navigator,
    cookieEnabled: { value: true }
    javaEnabled:   { value: -> false }
    platform:      { value: 'node' }
    plugins:       { value: [] }
    userAgent:     { value: browser.userAgent }
    language:      { value: browser.language }
    vendor:        { value: "Zombie Industries" }

  # Add cookies, storage, alerts/confirm, XHR, WebSockets, JSON, Screen, etc
  Object.defineProperty window, "cookies",
    get: ->
      return browser.cookies.serialize(@location.hostname, @location.pathname)
  browser._storages.extend(window)
  browser._interact.extend(window)

  Object.defineProperties window,
    File:           { value: File }
    Event:          { value: Events.Event }
    screen:         { value: new Screen() }
    MouseEvent:     { value: Events.MouseEvent }
    MutationEvent:  { value: Events.MutationEvent }
    UIEvent:        { value: Events.UIEvent }

  # Base-64 encoding/decoding
  window.atob = (string)->
    new Buffer(string, "base64").toString("utf8")
  window.btoa = (string)->
    new Buffer(string, "utf8").toString("base64")

  # Constructor for XHLHttpRequest
  window.XMLHttpRequest = ->
    return new XMLHttpRequest(window)

  # Constructor for EventSource, URL is relative to document's.
  window.EventSource = (url)->
    url = HTML.resourceLoader.resolve(document, url)
    window.setInterval((->), 100) # We need this to trigger event loop
    return new EventSource(url)

  # Web sockets
  window.WebSocket = (url, protocol)->
    url = HTML.resourceLoader.resolve(document, url)
    origin = "#{window.location.protocol}//#{window.location.host}"
    return new WebSocket(url, origin: origin, protocol: protocol)

  window.Image = (width, height)->
    img = new HTML.HTMLImageElement(window.document)
    img.width = width
    img.height = height
    return img

  # DataView: get from globals
  window.DataView = DataView

  window.XPathException   = XPath.XPathException
  window.XPathExpression  = XPath.XPathExpression
  window.XPathEvaluator   = XPath.XPathEvaluator
  window.XPathResult      = XPath.XPathResult

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
    setTimeout:
      value: eventQueue.setTimeout.bind(eventQueue)
    clearTimeout:
      value: eventQueue.clearTimeout.bind(eventQueue)
    setInterval:
      value: eventQueue.setInterval.bind(eventQueue)
    clearInterval:
      value: eventQueue.clearInterval.bind(eventQueue)
    setImmediate:
      value: (fn) -> eventQueue.setTimeout(fn, 0)
    clearImmediate:
      value: eventQueue.clearTimeout.bind(eventQueue)


  # -- Opening and closing --

  # Open one window from another.
  window.open = (url, name, features)->
    url = url && HTML.resourceLoader.resolve(document, url)
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

  history.updateLocation(window, url)

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
  Object.defineProperties window,
    history:
      value: windowHistory

  # Window is now open, next load the document.
  browser.emit("opened", window)

  # Form submission uses this
  window._submit = ({url, method, encoding, params, target })->
    url = HTML.resourceLoader.resolve(document, url)
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

  # Load the document associated with this window.
  loadDocument document: document, history: history, url: url, method: method, encoding: encoding, params: params
  return window


# Load document. Also used to submit form.
loadDocument = ({ document, history, url, method, encoding, params })->
  window = document.window
  browser = window.browser
  window._response = {}

  # Called on wrap up to update browser with outcome.
  done = (error)->
    if error
      browser.emit("error", error)
    else
      browser.emit("loaded", document)

  method = (method || "GET").toUpperCase()
  if method == "POST"
    headers =
      "content-type": encoding || "application/x-www-form-urlencoded"

  # Let's handle the specifics of each protocol
  { protocol, pathname } = URL.parse(url)
  switch protocol
    when "about:"
      document.open()
      document.write("<html><body></body></html>")
      document.close()
      browser.emit("loaded", document)

    when "javascript:"
      try
        window._evaluate(pathname, "javascript:")
        browser.emit("loaded", document)
      catch error
        browser.emit("error", error)

    when "http:", "https:", "file:"
      # Proceeed to load resource ...
      headers = headers || {}
      unless headers.referer
        # HTTP header Referer, but Document property referrer
        headers.referer = document.referrer
      # Tell the browser we're looking for an HTML document
      headers.accept = "text/html"

      window._eventQueue.http method, url, headers: headers, params: params, target: document, (error, response)->
        if error
          # 4xx/5xx we get an error with an HTTP response
          if response
            window._response = response
            history.updateLocation(window, response.url)

          # Error in body of page helps with debugging
          message = (response && response.body) || error.message || error
          document.open()
          document.write("<html><body>#{message}</body></html>")
          document.close()
          return

        window._response = response
        # JSDOM fires load event on document but not on window
        windowLoaded = (event)->
          document.removeEventListener("load", windowLoaded)
          window.dispatchEvent(event)
        document.addEventListener("load", windowLoaded)

        # Handle meta refresh.  Automatically reloads new location and counts
        # as a redirect.
        #
        # If you need to check the page before refresh takes place, use this:
        #   browser.wait({
        #     function: function() {
        #       return browser.query("meta[http-equiv='refresh']");
        #     }
        #   });
        handleRefresh = ->
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

        # JSDOM fires load event on document but not on window
        contentLoaded = (event)->
          document.removeEventListener("DOMContentLoaded", contentLoaded)
          window.dispatchEvent(event)
          handleRefresh()
        document.addEventListener("DOMContentLoaded", contentLoaded)

        # Give event handler chance to register listeners.
        window.browser.emit("loading", document)

        body = response.body
        unless /<html>/.test(body)
          body = "<html><body>#{body || ""}</body></html>"

        history.updateLocation(window, response.url)
        document.open()
        document.write(body)
        document.close()

        if document.documentElement
          browser.emit("loaded", document)
        else
          browser.emit("error", new Error("Could not parse document at #{url}"))

    else # but not any other protocol for now
      browser.emit("error", new Error("Cannot load resource #{url}, unsupported protocol"))


# Wrap dispatchEvent to support _windowInScope and error handling.
jsdomDispatchElement = HTML.Element.prototype.dispatchEvent
HTML.Node.prototype.dispatchEvent = (event)->
  self = this
  # Could be node, window or document
  document = self.ownerDocument || self.document || self
  window = document.parentWindow
  browser = window.browser
  browser.emit("event", event, self)

  try
    # The current window, postMessage and window.close need this
    [originalInScope, browser._windowInScope] = [browser._windowInScope, window]
    # Inline event handlers rely on window.event
    window.event = event
    return jsdomDispatchElement.call(self, event)
  catch error
    browser.emit("error", error)
  finally
    delete window.event
    browser._windowInScope = originalInScope


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


# File access, not implemented yet
class File
