# Create and return a new Window object.
#
# Also responsible for creating associated document and loading it.


Console     = require("./console")
EventLoop   = require("./eventloop")
EventSource = require("eventsource")
History     = require("./history")
JSDOM       = require("jsdom")
WebSocket   = require("ws")
Scripts     = require("./scripts")
URL         = require("url")

Events      = JSDOM.dom.level3.events
HTML        = JSDOM.dom.level3.html


# The current window in context.  Set during _evaluate, used by postMessage.
inContext = null


# Create and return a new Window.
#
# Parameters
# browser   - Browser that owns this window
# data      - Data to submit (used by forms)
# encoding  - Encoding MIME type (used by forms)
# history   - This window shares history with other windows
# method    - HTTP method (used by forms)
# name      - Window name (optional)
# opener    - Opening window (window.open call)
# parent    - Parent window (for frames)
# url       - Set document location to this URL upon opening
createWindow = ({ browser, data, encoding, history, method, name, opener, parent, url })->  
  name ||= ""
  url ||= "about:blank"

  window = JSDOM.createWindow(HTML)
  global = window.getGlobal()
  # window`s have a closed property defaulting to false
  closed = false

  # Access to browser
  Object.defineProperty window, "browser",
    value: browser
    enumerable: true

  # -- Document --

  # Each window has its own document
  document = createDocument(browser, window)
  Object.defineProperty window, "document",
    value: document
    enumerable: true

  # Each top-level window has its own event loop, iframes use the eventloop of
  # the main window, otherwise things get messy (wait, pause, etc).
  if parent
    eventLoop = parent._eventLoop
    eventLoop.apply(window)
  else
    eventLoop = new EventLoop(window)
  Object.defineProperty window, "_eventLoop",
    value: eventLoop


  # -- DOM Window features

  Object.defineProperty window, "name",
    value: name
    enumerable: true
  # If this is an iframe within a parent window
  if parent
    Object.defineProperty window, "parent",
      value: parent.getGlobal()
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
    value: opener && opener.getGlobal()
    enumerable: true

  # Window title is same as document title
  Object.defineProperty window, "title",
    get: ->
      return document.title
    set: (title)->
      document.title = title
    enumerable: true

  Object.defineProperty window, "console",
    value: new Console(browser)
    enumerable: true

  # javaEnabled, present in browsers, not in spec Used by Google Analytics see
  # https://developer.mozilla.org/en/DOM/window.navigator.javaEnabled
  Object.defineProperties window.navigator,
    cookieEnabled: { value: true }
    javaEnabled:   { value: -> false }
    plugins:       { value: [] }
    userAgent:     { value: browser.userAgent }
    vendor:        { value: "Zombie Industries" }
 
  # Add cookies, storage, alerts/confirm, XHR, WebSockets, JSON, Screen, etc
  browser._cookies.extend(window)
  browser._storages.extend(window)
  browser._interact.extend(window)
  browser._xhr.extend(window)

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

  window.resizeTo = (width, height)->
    window.outerWidth = window.innerWidth = width
    window.outerHeight = window.innerHeight = height
  window.resizeBy = (width, height)->
    window.resizeTo(window.outerWidth + width,  window.outerHeight + height)

  # Help iframes talking with each other
  window.postMessage = (data, targetOrigin)->
    document = window.document
    return unless document # iframe not loaded
    # Create the event now, but dispatch asynchronously
    event = document.createEvent("MessageEvent")
    event.initEvent("message", false, false)
    event.data = data
    # Window A (source) calls B.postMessage, to determine A we need the
    # caller's window.
    event.source = inContext
    origin = event.source.location
    event.origin = URL.format(protocol: origin.protocol, host: origin.host)
    process.nextTick ->
      window._eventLoop.dispatch(window, event)


  # -- JavaScript evaluation 

  # Evaulate in context of window. This can be called with a script (String) or a function.
  window._evaluate = (code, filename)->
    try
      inContext = window # the current window, postMessage needs this
      if typeof(code) == "string" || code instanceof String
        global.run(code, filename)
      else if code
        code.call(global)
    finally
      browser.emit("evaluated", window, code)
      inContext = null

  # Default onerror handler.
  window.onerror = (event)->
    error = event.error || new Error("Error loading script")
    browser.emit("error", error)


  # -- Opening and closing --

  # Open one window from another.
  window.open = (url, name, features)->
    url = url && HTML.resourceLoader.resolve(document, url)
    return browser.open(name: name, url: url, opener: window)

  # Indicates if window was closed
  Object.defineProperty window, "closed",
    get: -> closed
    enumerable: true

  # We need the JSDOM method that disposes of the context, but also over-ride
  # with our method that checks permission and removes from windows list
  dispose = window.close.bind(window)

  # Actualy window.close checks who's attempting to close the window.
  window.close = ->
    # Only opener window can close window; any code that's not running from
    # within a window's context can also close window.
    if inContext == opener || inContext == null
      browser.emit("inactive", window)
      dispose()
      closed = true
      browser.emit("closed", window)
    else
      browser.log("Scripts may not close windows that were not opened by script")
    return

  # Window is now open, next load the document.
  browser.emit("opened", window)


  # -- Navigating --

  history.updateLocation(window, url)

  # Each window maintains its own view of history
  windowHistory = 
    forward:      history.go.bind(history, 1)
    back:         history.go.bind(history, -1)
    go:           history.go.bind(history)
    pushState:    history.pushState.bind(history)
    replaceState: history.replaceState.bind(history)
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

  load = ({ url, method, encoding , data })->
    loadDocument document, url: url, method: method, encoding: encoding, referer: history.url, data: data, (error, newUrl)->
      if error
        browser.emit("error", error)
        return
      # If URL changed (redirects and friends) update window location
      if newUrl
        history.updateLocation(window, newUrl)
      browser.emit("loaded", document)
      # Fire onload event on window.
      onload = document.createEvent("HTMLEvents")
      onload.initEvent("load", false, false)
      window.dispatchEvent(onload)

  # Load the document associated with this window.
  load url: url, method: method, encoding: encoding, data: data
  # Form submission uses this
  # FIXME
  window._submit = load

  return window


# Create an empty document.  Each window gets a new document.
createDocument = (browser, window)->
  # Create new DOM Level 3 document, add features (load external resources,
  # etc) and associate it with current document. From this point on the browser
  # sees a new document, client register event handler for
  # DOMContentLoaded/error.
  jsdom_opts =
    deferClose:                 true
    features:
      MutationEvents:           "2.0"
      ProcessExternalResources: []
      FetchExternalResources:   ["iframe"]
    parser:                     browser.htmlParser

  if browser.runScripts
    jsdom_opts.features.ProcessExternalResources.push("script")
    jsdom_opts.features.FetchExternalResources.push("script")
  if browser.loadCSS
    jsdom_opts.features.FetchExternalResources.push("css")

  document = JSDOM.jsdom(null, HTML, jsdom_opts)

  # Add support for running in-line scripts
  if browser.runScripts
    Scripts.addInlineScriptSupport(document)


  # Tie document and window together
  Object.defineProperty document, "window",
    value: window
  Object.defineProperty document, "parentWindow",
    value: window.parent # JSDOM property?

  Object.defineProperty document, "location",
    get: ->
      return window.location
    set: (url)->
      window.location = url
  Object.defineProperty document, "URL",
    get: ->
      return window.location.href
    
  return document


# Load document. Also used to submit form.
loadDocument = (document, { url, method, encoding, data, referer }, callback)->
  window = document.window
  browser = window.browser
  callback ||= ->

  method = (method || "GET").toUpperCase()
  if method == "POST"
    headers =
      "content-type": encoding || "application/x-www-form-urlencoded"

  # Let's handle the specifics of each protocol
  { protocol, pathname } = URL.parse(url)
  switch protocol
    when "about:"
      callback(null)

    when "javascript:"
      try
        window._evaluate(pathname, "javascript:")
        callback(null)
      catch error
        callback(error)

    when "http:", "https:", "file:"
      # Proceeed to load resource ...
      request =
        url:      url
        method:   (method || "GET").toUpperCase() 
        headers:  (headers && Object.create(headers)) || {}
        data:     data
      if referer
        request.headers.referer = referer
         
      window._eventLoop.request request, (error, response)->
        if error
          document.open()
          document.write(error.message || error)
          document.close()
          callback(error)
        else
          browser.response = [response.statusCode, response.headers, response.body]
          # For responses that contain a non-empty body, load it.  Otherwise, we
          # already have an empty document in there courtesy of JSDOM.
          if response.body
            document.open()
            document.write(response.body)
            document.close()

          if /#/.test(response.url)
            hashChange = document.createEvent("HTMLEvents")
            hashChange.initEvent("hashchange", true, false)
            window._eventLoop.dispatch(window, hashChange)

          # Error on any response that's not 2xx, or if we're not smart enough to
          # process the content and generate an HTML DOM tree from it.
          if response.statusCode >= 400
            callback(new Error("Server returned status code #{response.statusCode} from #{url}"), response.url)
          else if document.documentElement
            callback(null, response.url)
          else
            callbacK(new Error("Could not parse document at #{url}"), response.url)
      
    else # but not any other protocol for now
      callback(new Error("Cannot load resource #{url}, unsupported protocol"))


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


module.exports = createWindow

