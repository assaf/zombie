# Tab management.
#
# Each browser has a set of open tabs, each tab having one current window.
#
# The set of tabs is an array, and you can access each tab by its index number.
# Note that tab order will shift when you close a window.  You can also get the
# number of tabs (tabs.length) and iterate over then (map, filter, forEach).
#
# If a window has a name, you can also access it by name.  Since names may
# conflict with reserved properties/methods, you may need to use the find
# method.
#
# You can get the window of the currently selected tab (tabs.current) or its
# index number (tabs.index).
#
# To change the currently selected tab, set tabs.current to a different window,
# a window name or the tab index number.  This changes the window returned from
# browser.window.
#
# Examples
#
#   firstTab = browser.tabs[0]
#   fooTab = browser.tabs["foo"]
#   openTab = brower.tabs.find("open")
#
#   old = browser.current
#   foo = browser.tabs["foo"]
#   browser.current = foo
#   ...
#   browser.current = old
#
#   window = browser.tabs.open(url: "http://example.com")
#
#   count = browser.tabs.length
#   browser.tabs.close(window)
#   assert(browser.tabs.length == count - 1)
#   browser.tabs.close()
#   assert(browser.tabs.length == count - 2)
#
#   browser.tabs.closeAll()
#   assert(browser.tabs.length == 0)
#   assert(browser.tabs.current == null)


createHistory = require("./history")


createTabs = (browser)->
  tabs = []
  current = null

  Object.defineProperties tabs,

    # current property has a fancy setter
    current:
      get: ->
        return current
      set: (window)->
        window = tabs.find(window) || window
        return unless ~tabs.indexOf(window)
        if window && window != current
          if current
            browser.emit("inactive", current)
          current = window
          browser.emit("active", current)
        return

    # Opens and returns a tab.  If an open window by the same name already exists,
    # opens this window in the same tab.  Omit name or use "_blank" to always open
    # a new tab.
    #
    # name    - Window name (optional)
    # opener  - Opening window (window.open call)
    # url     - Set document location to this URL upon opening
    open:
      value: (options = {})->
        { name, opener, url } = options
        # If name window in open tab, reuse that tab. Otherwise, open new window.
        if name && window = this.find(name.toString())
          # Select this as the currenly open tab. Changing the location would then
          # select a different window.
          tabs.current = window
          if url
            window.location = url
          return current
        else
          if name == "_blank" || !name
            name = ""

          # When window changes we need to change tab slot. We can't keep the index
          # around, since tab order changes, so we look up the currently known
          # active window and switch that around.
          active = null
          focus = (window)->
            if window && window != active
              index = tabs.indexOf(active)
              if ~index
                tabs[index] = window
              if tabs.current == active
                tabs.current = window
              active = window
            browser._eventLoop.setActiveWindow(window)

          history = createHistory(browser, focus)
          window = history(name: name, opener: opener, url: url)
          this.push(window)
          if name && (Object.propertyIsEnumerable(name) || !this[name])
            this[name] = window
          active = window
          # Select this as the currenly open tab
          tabs.current = window
          return window


    # Index of currently selected tab.
    index:
      get: ->
        return this.indexOf(current)


    # Returns window by index or name. Use this for window names that shadow
    # existing properties (e.g. tabs["open"] is a function, use
    find:
      value: (name)->
        if tabs.propertyIsEnumerable(name)
          return this[name]
        for window in this
          if window.name == name
            return window
        return null


    # Close an open tab.  With no arguments, closes the currently open tab.  With
    # one argument, closes the tab for that window.  You can pass a window, window
    # name or index number.
    close:
      value: (window)->
        if arguments.length == 0
          window = current
        else
          window = this.find(window) || window
        if ~this.indexOf(window)
          window.close()
        return


    # Closes all open tabs/windows.
    closeAll:
      value: ->
        while @length > 0
          this.close()

  # We're notified when window is closed (by any means), and take that tab out
  # of circulation.
  browser.on "closed", (window)->
    index = tabs.indexOf(window)
    if ~index
      tabs.splice(index, 1)
      # If we closed the currently open tab, need to select another window.
      if window == current
        # Don't emit inactive event for closed window.
        current = tabs[index - 1] || tabs[0]
        if current
          browser.emit("active", current)

  return tabs


module.exports = createTabs
