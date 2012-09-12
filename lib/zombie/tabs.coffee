# Tab management.
#
# Each browser has a set of open tabs, each tab has one open window.  You can
# access tabs by index number, or by window name.  The currently open tab is
# available as browser.window or browser.tabs.current.
#
#  firstTab = browser.tabs[0]
#  fooTab = browser.tabs["foo"]
#
#  open = browser.current
#  foo = browser.tabs["foo"]
#  browser.current = foo
#  ...
#  browser.current = open
#
#  window = browser.tabs.open(url: "http://example.com")
#
#  open = browser.tabs.length
#  browser.tabs.close(window)
#  assert(browser.tabs.length == open - 1)
#
#  browser.tabs.closeAll()
#  assert(browser.tabs.length == 0)
#  assert(browser.tabs.current == null)


createWindow = require("./window")


class Tabs extends Array
  constructor: (browser)->
    @browser = browser
    tabs = this

    # current property has a fancy setter
    current = null
    Object.defineProperty this, "current",
      enumerable: false
      get: ->
        return current
      set: (window)->
        window = tabs[window] || window
        return unless ~tabs.indexOf(window)
        if window && window != current
          if current
            browser.emit("inactive", current)
          current = window
          browser.emit("active", current)
        return

    # Index of currently selected tab.
    Object.defineProperty this, "index",
      get: ->
        return this.indexOf(current)

    # We're notified when window is closed (by any means), and take that tab out
    # of circulation.
    browser.on "closed", (window)->
      index = tabs.indexOf(window)
      if index >= 0
        tabs.splice(index, 1)
        # If we closed the currently open tab, need to select another window.
        if window == current
          # Don't emit inactive event for closed window.
          current = tabs[index - 1] || tabs[0]
          if current
            browser.emit("active", current)

  # Opens and returns a tab.  If an open window by the same name already exists,
  # opens this window in the same tab.  Omit name or use "_blank" to always open
  # a new tab.
  #
  # name    - Window name (optional)
  # opener  - Opening window (window.open call)
  # url     - Set document location to this URL upon opening
  open: (options = {})->
    { name, opener, url } = options
    # If name window in open tab, reuse that tab. Otherwise, open new window.
    if existing = this[name]
      window = createWindow(browser: @browser, name: name, opener: opener, url: url)
      this[this.indexOf(existing)] = window
      this[name] = window
    else
      if name == "_blank" || !name
        name = ""
      window = createWindow(browser: @browser, name: name, opener: opener, url: url)
      this.push(window)
      if name
        this[name] = window
    # Select this as the currenly open tab
    @current = window
    return window

  # Close an open tab.  With no arguments, closes the currently open tab.  With
  # one argument, closes the tab for that window.  You can pass a window, window
  # name or index number.
  close: (window)->
    if arguments.length == 0
      window = @current
    else
      window = this[window] || window
    if ~this.indexOf(window)
      window.close()
    return

  # Closes all open tabs/windows.
  closeAll: ->
    while this.length > 0
      this.close(this.length - 1)
    return


module.exports = Tabs

