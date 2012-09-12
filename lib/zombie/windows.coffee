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


createWindow = require("./window")


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
  open: ({ name, opener, parent, url })->
    name ||= @_browser.name || ""
    create = =>
      return createWindow(browser: @_browser, name: name, opener: opener, parent: parent, url: url)

    # If this is an iframe, create a named window but don't keep a reference
    # to it here. Let the document handle that,
    if parent
      window = create()
    else
      # If window name is _blank, we always create a new window.
      # Otherwise, we return existing window and allow lookup by name.
      if name == "_blank"
        window = create()
      else
        window = @_named[name] ||= create()
      @_stack.push window

    # If this is a top window, it becomes the current browser window
    unless parent
      @select window
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
    window = @_named[window] || @_stack[window] || window || @_current
    # Make sure we only close an existing window, and we need index if we're
    # closing the current window
    index = @_stack.indexOf(window)
    return unless index >= 0
  
    # Make sure we only close the window (and dispose of its context) once
    unless window.closed
      window.close()
      delete @_named[window.name]
      @_stack.splice(index, 1)
      # If we closed the currently open window, switch to the previous window.
      if window == @_current
        @_current = null
        if index > 0
          @select @_stack[index - 1]
        else
          @select @_stack[0]
    return

  # Select specified window as the current window.
  select: (window)->
    window = @_named[window] || @_stack[window] || window
    return unless ~@_stack.indexOf(window)
    if window != @_current
      if @_current
        @_browser.emit "inactive", @_current
      @_current = window
      @_browser.emit "active", window
    return

  # Returns the currently open window.
  @prototype.__defineGetter__ "current", ->
    return @_current



module.exports = Windows
