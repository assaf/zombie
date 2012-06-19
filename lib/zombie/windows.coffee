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
    name = options.name || @_browser.name || ""
    # If this is an iframe, create a named window but don't keep a reference
    # to it here. Let the document handle that,
    if options.parent
      window = @_create(name, options)
      pane = window._pane
    else
      # If window name is _blank, we always create a new window.
      # Otherwise, we return existing window and allow lookup by name.
      if name == "_blank"
        window = @_create(name, options)
        pane = window._pane
      else
        pane = @_named[name]
        if pane
          window = pane.current
        else
          window = @_create(name, options)
          pane = window._pane
          @_named[name] = pane
      @_stack.push pane
    # If caller supplies URL, use it.  If this is existing window, return
    # without changing location (or contents).  Otherwise, start with empty
    # document.

    # we do not want to fork for a new open
    pane._nofork = true
    if options.url
      window.location = options.url
    else if !window.document
      window.location = "about:blank"
    
    # If this is a top window, it becomes the current browser window
    unless options.parent
      @select window
    return window
  
  # Returns specific window by its name or position (e.g. "foo" returns the
  # window named "foo", while 1 returns the second window)
  get: (name_or_index)->
    pane = @_named[name_or_index] || @_stack[name_or_index]
    return pane?.current

  # Returns all open windows.
  all: ->
    return @_stack.map (pane) -> pane.current

  # Number of open windows
  @prototype.__defineGetter__ "count", ->
    return @_stack.length

  # Close the specified window (last window if unspecified)
  close: (window)->
    pane = @_named[window] || @_stack[window] || window || @_current
    # Make sure we only close an existing window, and we need index if we're
    # closing the current window
    index = @_stack.indexOf(pane)
    return unless index >= 0
    
    # Set window's closed property to true
    pane.current.closed = pane.closed = true

    delete @_named[pane.name]
    @_stack.splice(index, 1)
    # If we closed the currently open window, switch to the previous window.
    if pane == @_current
      if index > 0
        @select @_stack[index - 1]
      else
        @select @_stack[0]
    return
    
  # go backwards in the specified window (last window if unspecified)
  back: (window) ->
    go -1, window
  forward: (window) ->
    go 1, window
  go: (count,window) ->
    pane = @_named[window] || @_stack[window] || window?._pane || @_current
    # Make sure we only go to an existing window, and we need index if we're
    # working on the current window
    index = @_stack.indexOf(pane)
    return unless index >= 0
    
    pane.index += count
    # when we go, we do nofork once
    pane._nofork = true

  # Select specified window as the current window.
  select: (window)->
    pane = @_named[window] || @_stack[window] || window._pane || window
    return unless ~@_stack.indexOf(pane)
    [previous, @_current] = [@_current, pane]
    window = pane.current
    if window.document && previous != pane
      # Fire onfocus and onblur event
      onfocus = window.document.createEvent("HTMLEvents")
      onfocus.initEvent "focus", false, false
      window.dispatchEvent onfocus
      if previous
        onblur = window.document.createEvent("HTMLEvents")
        onblur.initEvent "blur", false, false
        previous.current.dispatchEvent onblur
    return

  # Returns the currently open window.
  @prototype.__defineGetter__ "current", ->
    return @_current.stack[@_current.index]

  # This actually handles creation of a new window.
  _create: (name, { parent, opener, history, screen }, pane)->
    window = JSDOM.createWindow(HTML)
    global = window.getGlobal()

    Object.defineProperty window, "browser", value: @_browser

    # Add event loop features (setInterval, dispatchEvent, etc)
    eventloop = @_browser._eventloop
    eventloop.apply window

    # -- DOM Window features

    Object.defineProperty window, "name", value: name || ""
    
    Object.defineProperty window, "parent", get: -> @_pane.parent.current.getGlobal()
    Object.defineProperty window, "top", get: -> @_pane.top.current.getGlobal()
    # Each window maintains its own history
    Object.defineProperty window, "history", value: history || new History(window)

    # If this was opened from another window
    Object.defineProperty window, "opener", get: -> 
      return @_pane.opener.current.getGlobal()

    # Window title is same as document title
    Object.defineProperty window, "title",
      get: ->
        return @document.title
      set: (title)->
        @document.title = title

    # window`s have a closed property defaulting to false
    window.closed = false

    # javaEnabled, present in browsers, not in spec Used by Google Analytics see
    # https://developer.mozilla.org/en/DOM/window.navigator.javaEnabled
    Object.defineProperties window.navigator,
      cookieEnabled: { value: true }
      javaEnabled:   { value: -> false }
      plugins:       { value: [] }
      vendor:        { value: "Zombie Industries" }
   
    # Add cookies, storage, alerts/confirm, XHR, WebSockets, JSON, Screen, etc
    @_browser._cookies.extend window
    @_browser._storages.extend window
    @_browser._interact.extend window
    @_browser._xhr.extend window

    Object.defineProperties window,
      File:           { value: File }
      Event:          { value: Events.Event }
      screen:         { value: screen || new Screen() }
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

    window.resizeTo = (width, height)->
      window.outerWidth = window.innerWidth = width
      window.outerHeight = window.innerHeight = height
    window.resizeBy = (width, height)->
      window.resizeTo window.outerWidth + width,  window.outerHeight + height

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

    # -- Focusing --
    
    # If window goes in/out of focus, notify focused input field
    window.addEventListener "focus", (event)->
      if window.document.activeElement
        onfocus = window.document.createEvent("HTMLEvents")
        onfocus.initEvent "focus", false, false
        window.document.activeElement.dispatchEvent onfocus
    window.addEventListener "blur", (event)->
      if window.document.activeElement
        onblur = window.document.createEvent("HTMLEvents")
        onblur.initEvent "blur", false, false
        window.document.activeElement.dispatchEvent onblur

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
        @close(window._pane)
      else
        @_browser.log("Scripts may not close windows that were not opened by script")
      return

    window.go = (amount) =>
      return @go(amount,window)
    window.back = () =>
      return @back(window)
    window.forward = () =>
      return @forward(window)

    # when we set the document, we need to reset the window to a new window, with the existing pane
    windows = @
    Object.defineProperty window, "document",
      get: ->
        return @_document
      set: (document) ->
        win = @
        # create a new window in the pane to use
        if !@_pane._nofork
          win = windows._create(@name,{history:@history},@_pane)

        # do _nofork once or twice for each open window:
        #   once for the new open
        #   second time if the initial page is about:blank
        # also no fork when we are setting a document because we moved somewhere in our history
        locn = win.location.toString()
        if locn != "about:blank" && locn != "javascript:false"
          delete @_pane._nofork
        #win._window = @._window = win
        win._document = document
      
    Object.defineProperty window, "_window",
      get: ->
        return @_pane.current
      set: (win)->
        @_window = win
      
    # create the pane if necessary
    if pane != false
      if !pane
        pane = {name:name,stack:[], index: -1}
        Object.defineProperty pane, "current",
          get: ->
            return @stack[@index]
          set: ()->
            # do nothing, you cannot play with this
            return
        if opener
          pane.opener = opener._pane
        # If this is an iframe within a parent window
        if parent
          pane.parent = parent._pane
          pane.top = parent.top._pane
        else
          pane.parent = pane.top = pane
          
      pane.stack.push window
      pane.index++
      window._pane = pane

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
