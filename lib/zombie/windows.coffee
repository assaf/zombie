# Each browser maintains a collection of windows, and this class abstracts it.
# You can use it to list, switch and close windows.
#
# It also abstracts all the gory details of window creation, frames need that
# too.
#
# For example:
#
#   # Get currently open window
#   current = browser.windows.current
#   # Switch to first open window
#   browser.windows.select(1)
#   # Close currently open window
#   browser.windows.close()


Console     = require("./console")
History     = require("./history")
JSDOM       = require("jsdom")
HTML        = JSDOM.dom.level3.html
URL         = require("url")
EventSource = require("eventsource")
WebSocket   = require("ws")
Events      = JSDOM.dom.level3.events


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

  # Number of open windows
  @prototype.__defineGetter__ "count", ->
    return @_stack.length

  # Close the specified window (last window if unspecified)
  close: (window)->
    window ||= @_current
    # Make sure we only close an existing window, and we need index if we're
    # closing the current window
    index = @_stack.indexOf(window)
    return unless index >= 0
  
    delete @_named[window.name]
    @_stack.splice(index, 1)
    # If we closed the currently open window, switch to the previous window.
    if window == @_current
      if index > 0
        @_current = @_stack[index - 1]
      else
        @_current = @_stack[0]
    return

  # Select specified window as the current window.
  select: (window)->
    return unless window
    window = @_named[window] || @_stack[window] || window
    return unless ~@_stack.indexOf(window)
    @_current = window

  # Returns the currently open window.
  @prototype.__defineGetter__ "current", ->
    return @_current

  # This actually handles creation of a new window.
  _create: ({ name, parent, opener })->
    window = JSDOM.createWindow(HTML)
    global = window.getGlobal()
    @_stack.push window

    Object.defineProperty window, "browser", value: @_browser
    # Add event loop features (setInterval, dispatchEvent, etc)
    eventloop = @_browser._eventloop
    eventloop.apply window

    # -- DOM Window features

    Object.defineProperty window, "name", value: name || ""
    # If this is an iframe within a parent window
    if parent
      Object.defineProperty window, "parent", value: parent.getGlobal()
      Object.defineProperty window, "top", value: parent.top.getGlobal()
    else
      Object.defineProperty window, "parent", value: window.getGlobal()
      Object.defineProperty window, "top", value: window.getGlobal()
    # Each window maintains its own history
    Object.defineProperty window, "history", value: new History(window)
    # If this was opened from another window
    Object.defineProperty window, "opener", value: opener?.getGlobal()

    # Window title is same as document title
    window.__defineGetter__ "title", ->
      return @document.title
    window.__defineSetter__ "title", (title)->
      @document.title = title

    # Present in browsers, not in spec Used by Google Analytics see
    # https://developer.mozilla.org/en/DOM/window.navigator.javaEnabled
    window.navigator.javaEnabled = ->
      return false
   
    # Add cookies, storage, alerts/confirm, XHR, WebSockets, JSON, Screen, etc
    @_browser._cookies.extend window
    @_browser._storages.extend window
    @_browser._interact.extend window
    @_browser._xhr.extend window
    window.File = File
    window.screen = new Screen()
    window.JSON = JSON

    window.Event = Events.Event
    window.UIEvent = Events.UIEvent
    window.MouseEvent = Events.MouseEvent
    window.MutationEvent = Events.MutationEvent

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
      event.source = Windows.inContext
      origin = event.source.location
      event.origin = URL.format(protocol: origin.protocol, host: origin.host)
      process.nextTick ->
        eventloop.dispatch window, event

    # -- JavaScript evaluation 

    # Evaulate in context of window. This can be called with a script (String) or a function.
    window._evaluate = (code, filename)->
      try
        Windows.inContext = window # the current window, postMessage needs this
        if typeof code == "string" || code instanceof String
          global.run code, filename
        else
          code.call global
      finally
        Windows.inContext = null

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
