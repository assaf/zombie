# Tab management.


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

    # Dump list of all open tabs to stdout or output stream.
    dump:
      value: (output = process.stdout)->
        if tabs.length == 0
          output.write "No open tabs.\n"
        else
          for window in tabs
            output.write "Window #{window.name || "unnamed"} open to #{window.location.href}\n"

    # Opens and returns a tab.  If an open window by the same name already exists,
    # opens this window in the same tab.  Omit name or use "_blank" to always open
    # a new tab.
    #
    # name    - Window name (optional)
    # opener  - Opening window (window.open call)
    # referer - Referrer
    # url     - Set document location to this URL upon opening
    open:
      value: (options = {})->
        { name, url } = options
        # If name window in open tab, reuse that tab. Otherwise, open new window.
        if name && window = @find(name.toString())
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
            browser.eventLoop.setActiveWindow(window)

          open = createHistory(browser, focus)
          options.url = url
          window = open(options)
          @push(window)
          if name && (Object.propertyIsEnumerable(name) || !this[name])
            this[name] = window
          active = window
          # Select this as the currenly open tab
          tabs.current = window
          return window


    # Index of currently selected tab.
    index:
      get: ->
        return @indexOf(current)


    # Returns window by index or name. Use this for window names that shadow
    # existing properties (e.g. tabs["open"] is a function, use
    find:
      value: (name)->
        if tabs.propertyIsEnumerable(name)
          return tabs[name]
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
          window = @find(window) || window
        if ~@indexOf(window)
          window.close()
        return


    # Closes all open tabs/windows.
    closeAll:
      value: ->
        windows = this.slice(0)
        for window in windows
          if window.close
            window.close()

  # We're notified when window is closed (by any means), and take that tab out
  # of circulation.
  browser.on "closed", (window)->
    index = tabs.indexOf(window)
    if ~index
      browser.emit("inactive", window)
      tabs.splice(index, 1)
      if tabs.propertyIsEnumerable(window.name)
        delete tabs[window.name]
      # If we closed the currently open tab, need to select another window.
      if window == current
        # Don't emit inactive event for closed window.
        if index > 0
          current = tabs[index - 1]
        else
          current = tabs[0]
        if current
          browser.emit("active", current)

  return tabs


module.exports = createTabs
