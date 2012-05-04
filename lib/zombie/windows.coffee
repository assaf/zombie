# Each browser maintains a collection of windows, and this class abstracts it.
#
# It also abstracts all the gory details of window creation, frames need that
# too.


Console     = require("./console")
History     = require("./history")
JSDOM       = require("jsdom")
HTML        = JSDOM.dom.level3.html
URL         = require("url")
EventSource = require("eventsource")
WebSocket   = require("ws")


class Windows
  constructor: (browser)->
    @_browser = browser
    # The named window
    @_named = {}
    @_stack = []
    # Always start out with one open window
    @open({})

  # Opens and returns a window. If a window by the same name already exists,
  # returns it.  Use "_blank" to always open a new window.
  #
  # Options are:
  # name   - Name of the window.
  # opener - When opening one window from another
  # parent - Parent window (for frames)
  # url    - If specified, opens that document
  open: (options = {})->
    # If this is an iframe, create a named window but don't keep a reference
    # to it here. Let the document handle that,
    # If window name is _blank, we always create a new window.
    # Otherwise, we return existing window and allow lookup by name.
    if options.name == "_blank" || options.parent
      window = @_create(options)
    else
      name = options.name || ""
      window = @_named[name] ||= @_create(options)

    # If caller supplies URL, use it.  If this is existing window, return
    # without changing location (or contents).  Otherwise, start with empty
    # document.
    if options.url
      window.location = options.url
    else if !window.document
      window.location = "about:blank"

    # If this is a top window, it becomes the current browser window
    unless options.parent
      @_current = window
    return window

  # Returns specific window by its name or position (e.g. "foo" returns the
  # window named "foo", while 1 returns the second window)
  get: (name_or_index)->
    return @_named[name_or_index] || @_stack[name_or_index]

  # Returns all open windows.
  all: ->
    return @_stack.slice()

  # Close the specified window
  close: (window)->
    delete @_named[window.name]
    @_stack = @_stack.filter((w)-> w != window)
    if @_current = window
      @_current = @_stack[@_stack.length - 1]
    return

  # Returns the currently open window.
  @prototype.__defineGetter__ "current", ->
    return @_current

  # This actually handles creation of a new window.
  _create: ({ name, parent, opener })->
    window = JSDOM.createWindow(HTML)
    @_stack.push window

    Object.defineProperty window, "browser", value: @_browser
    # Add event loop features (setInterval, dispatchEvent, etc)
    eventloop = @_browser._eventloop
    eventloop.apply window

    # -- DOM Window features

    Object.defineProperty window, "name", value: name || ""
    # If this is an iframe within a parent window
    if parent
      Object.defineProperty window, "parent", value: parent
      Object.defineProperty window, "top", value: parent.top
    else
      Object.defineProperty window, "parent", value: window
      Object.defineProperty window, "top", value: window
    # Each window maintains its own history
    Object.defineProperty window, "history", value: new History(window)
    # If this was opened from another window
    Object.defineProperty window, "opener", value: opener

    # Window title is same as document title
    window.__defineGetter__ "title", ->
      return @document.title
    window.__defineSetter__ "title", (title)->
      @document.title = title

    # Present in browsers, not in spec Used by Google Analytics see
    # https://developer.mozilla.org/en/DOM/window.navigator.javaEnabled
    Object.defineProperty window.navigator, "javaEnabled", value: false
   
    # Add cookies, storage, alerts/confirm, XHR, WebSockets, JSON, Screen, etc
    @_browser._cookies.extend window
    @_browser._storages.extend window
    @_browser._interact.extend window
    @_browser._xhr.extend window
    window.File = File
    window.screen = new Screen()
    window.JSON = JSON

    # Constructor for EventSource, URL is relative to document's.
    window.EventSource = (url)->
      url = URL.resolve(window.location, url)
      window.setInterval (->), 100 # We need this to trigger event loop
      return new EventSource(url)

    # Web sockets
    window.WebSocket = (url, protocol)->
      origin = "#{window.location.protocol}//#{window.location.host}"
      return new WebSocket(url, origin: origin, protocol: protocol)

    window.Image = (width, height)->
      img = new HTML.HTMLImageElement(window.document)
      img.width = width
      img.height = height
      return img
    window.console = new Console(@_browser.silent)

    # Help iframes talking with each other
    window.postMessage = (data, targetOrigin)=>
      document = window.document
      return unless document # iframe not loaded
      # Create the event now, but dispatch asynchronously
      event = document.createEvent("MessageEvent")
      event.initEvent "message", false, false
      event.data = data
      event.source = global.window
      origin = global.window.location
      event.origin = URL.format(protocol: origin.protocol, host: origin.host)
      process.nextTick ->
        eventloop.dispatch window, event

    # -- JavaScript evaluation 

    # Evaulate in context of window. This can be called with a script (String) or a function.
    window._evaluate = (code, filename)->
      try
        global.window = window # the current window, postMessage needs this
        if typeof code == "string" || code instanceof String
          window.run code, filename
        else
          code.call window
      finally
        global.window = null

    # Default onerror handler.
    window.onerror = (event)=>
      error = event.error || new Error("Error loading script")
      @_browser.emit "error", error

    # Open one window from another.
    window.open = (url, name, features)=>
      url = URL.resolve(window.location, url) if url
      return @open(url: url, name: name, opener: window)

    window.close = =>
      # Can only close a window opened from another window
      if opener
        @close(window)
      else
        @_browser.log("Scripts may not close windows that were not opened by script")
      return

    return window


class Screen
  constructor: ->
    @width = 1280
    @height = 800
    @left = 0
    @top = 0

  @prototype.__defineGetter__ "availLeft", -> 0
  @prototype.__defineGetter__ "availTop", -> 0
  @prototype.__defineGetter__ "availWidth", -> @width
  @prototype.__defineGetter__ "availHeight", -> @height
  @prototype.__defineGetter__ "colorDepth", -> 24
  @prototype.__defineGetter__ "pixelDepth", -> 24


class File


module.exports = Windows
