# Create and return a new Window object.


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
# browser - Browser that owns this window
# name    - Window name (optional)
# parent  - Parent window (for frames)
# opener  - Opening window (window.open call)
# url     - Set document location to this URL upon opening
createWindow = ({ browser, name, parent, opener, url })->  
  name ||= ""
  window = JSDOM.createWindow(HTML)
  global = window.getGlobal()
  # window`s have a closed property defaulting to false
  closed = false

  # Access to browser
  Object.defineProperty window, "browser",
    value: browser

  # Each window has its own document
  document = createDocument(browser)
  window.document = document
  document.window = document.parentWindow = window

  # Each window has its own event loop
  Object.defineProperty window, "_eventloop",
    value: new EventLoop(window)


  # -- DOM Window features

  Object.defineProperty window, "name",
    value: name
  # If this is an iframe within a parent window
  if parent
    Object.defineProperty window, "parent",
      value: parent.getGlobal()
    Object.defineProperty window, "top",
      value: parent.top.getGlobal()
  else
    Object.defineProperty window, "parent",
      value: global
    Object.defineProperty window, "top",
      value: global
  # Each window maintains its own history
  Object.defineProperty window, "history",
    value: new History(window)
  # If this was opened from another window
  Object.defineProperty window, "opener",
    value: opener && opener.getGlobal()

  # Window title is same as document title
  Object.defineProperty window, "title",
    get: ->
      return document.title
    set: (title)->
      document.title = title

  Object.defineProperty window, "console",
    value: new Console(browser)

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
    url = URL.resolve(window.location, url)
    window.setInterval((->), 100) # We need this to trigger event loop
    return new EventSource(url)

  # Web sockets
  window.WebSocket = (url, protocol)->
    url = URL.resolve(window.location, url)
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
  window.postMessage = (data, targetOrigin)=>
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
      window._eventloop.dispatch(window, event)

  # Fire onload event on window.
  document.addEventListener "DOMContentLoaded", (event)=>
    onload = document.createEvent("HTMLEvents")
    onload.initEvent("load", false, false)
    window.dispatchEvent(onload)


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
  window.onerror = (event)=>
    error = event.error || new Error("Error loading script")
    browser.emit("error", error)


  # -- Opening and closing --

  # Open one window from another.
  window.open = (url, name, features)=>
    url = URL.resolve(window.location, url) if url
    return browser.open(name: name, url: url, opener: window)

  # Indicates if window was closed
  Object.defineProperty window, "closed",
    get: -> closed

  # We need the JSDOM method that disposes of the context, but also over-ride
  # with our method that checks permission and removes from windows list
  internalClose = window.close.bind(window)

  # Actualy window.close checks who's attempting to close the window.
  window.close = ->
    # Only opener window can close window; any code that's not running from
    # within a window's context can also close window.
    if inContext == opener || inContext == null
      unless closed
        internalClose()
        closed = true
        browser.close(window)
        browser.emit("closed", window)
    else
      browser.log("Scripts may not close windows that were not opened by script")
    return

  # If caller supplies URL, use it.
  if url
    loadDocument(window, url)

  browser.emit("opened", window)
  return window


# Create an empty document.  Each window gets a new document.
createDocument = (browser)->
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

  # require("html5").HTML5
  if browser.runScripts
    jsdom_opts.features.ProcessExternalResources.push("script")
    jsdom_opts.features.FetchExternalResources.push("script")
  if browser.loadCSS
    jsdom_opts.features.FetchExternalResources.push("css")

  document = JSDOM.jsdom(null, HTML, jsdom_opts)

  # Add support for running in-line scripts
  if browser.runScripts
    Scripts.addInlineScriptSupport(document)
  return document


loadDocument = (window, url)->
  window.location = url


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


# File access, not implemented yet.
class File


module.exports = createWindow

