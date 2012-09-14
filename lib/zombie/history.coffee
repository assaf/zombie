# Window history.
#
# Each window belongs to a history. Think of history as a timeline, with
# currently active window, and multiple previous and future windows. From that
# window you can navigate backwards and forwards between all other windows that
# belong to the same history.
#
# Each window also has a container: either a browser tab or an iframe. When
# navigating in history, a different window (from the same history), replaces
# the current window within its container.
#
# Containers have access to the currently active window, not the history
# itself, so navigation has to alert the container when there's a change in the
# currently active window.
#
# The history does so by calling a "focus" function. To create the first
# window, the container must first create a new history and supply a focus
# function. The result is another function it can use to create the new window.
#
# From there on, it can navigate in history and add new windows by chaing the
# current location (or using assign/replace).
#
# It can be used like this:
#
#   active = null
#   focus = (window)->
#     active = window
#   history = createHistory(browser, focus)
#   window = history(url: url, name: name)


createWindow  = require("./window")
HTML          = require("jsdom").dom.level3.html
URL           = require("url")


# Creates and returns a new history.
#
# browser - The browser object
# focus   - The focus method, called when a new window is in focus
#
# Returns a function for opening a new window, which accepts:
# name      - Window name (optional)
# opener    - Opening window (window.open call)
# parent    - Parent window (for frames)
# url       - Set document location to this URL upon opening
createHistory = (browser, focus)->
  history = new History(browser, focus)
  return history.open.bind(history)


# Entry has the following properties:
# window      - Window for this history entry (may be shared with other entries)
# url         - URL for this history entry
# pushState   - Push state state
# next        - Next entry in history
# prev        - Previous entry in history
class Entry
  constructor: (@window, url, @pushState)->
    @url = URL.format(url)
    @next = @prev = null

  dispose: ->
    if @next
      @next.dispose()
    # TODO destroy this window

  append: (entry)->
    if @next
      @next.dispose()
    @next = entry
    entry.prev = this


class History
  constructor: (@browser, @focus)->
    @first = @current = null

  # Opens the first window and returns it.
  open: ({ name, opener, parent, url })->
    window = createWindow(browser: @browser, history: this, name: name, opener: opener, parent: parent, url: url)
    @current = @first = new Entry(window, url || window.location)
    return window

  # Add a new entry.  When a window opens it call this to add itself to history.
  addEntry: (window, url, pushState)->
    url ||= window.location
    entry = new Entry(window, url, pushState)
    this.updateLocation(window, url)
    @current.append(entry)
    @current = entry
    @focus(window)
 
  # Replace current entry with a new one.
  replaceEntry: (window, url, pushState)->
    url ||= window.location
    entry = new Entry(window, url, pushState)
    this.updateLocation(window, url)
    if @current == @first
      @current.dispose()
      @current = @first = entry
    else
      @current.prev.append(entry)
    @focus(window)

  # Update window location (navigating to new URL, same window, e.g pushState or hash change)
  updateLocation: (window, url)->
    history = this
    Object.defineProperty window, "location", 
      get: ->
        return new Location(history, url)
      set: (url)->
        history.assign(url)
      enumerable: true

  # Returns current URL.
  @prototype.__defineGetter__ "url", ->
    return @current?.url


  # -- Implementation of window.history --

  # This method is available from Location, used to navigate to a new page.
  assign: (url)->
    url = URL.format(url)
    if @current
      url = HTML.resourceLoader.resolve(@current.window.document, url)
      name = @current.window.name
    if @current && @current.url == url
      return # Not moving anywhere

    if hashChange(@current, url)
      window = @current.window
      @addEntry(window, url) # Reuse window with new URL
      event = window.document.createEvent("HTMLEvents")
      event.initEvent("hashchange", true, false)
      window._eventLoop.dispatch(window, event)
    else
      window = createWindow(browser: @browser, history: this, name: name, url: url)
      @addEntry(window, url)

  # This method is available from Location, used to navigate to a new page.
  replace: (url)->
    url = URL.format(url)
    if @current
      url = HTML.resourceLoader.resolve(@current.window.document, url)
      name = @current.window.name
    if @current && @current.url == url
      return # Not moving anywhere

    if hashChange(@current, url)
      window = @current.window
      @replaceEntry(window, url) # Reuse window with new URL
      event = window.document.createEvent("HTMLEvents")
      event.initEvent("hashchange", true, false)
      window._eventLoop.dispatch(window, event)
    else
      window = createWindow(browser: @browser, history: this, name: name, url: url)
      @replaceEntry(window, url)

  # This method is available from Location.
  go: (amount)->
    was = @current
    while amount > 0
      @current = @current.next if @current.next
      --amount
    while amount < 0
      @current = @current.prev if @current.prev
      ++amount

    # If moving from one page to another
    if @current && was && @current != was
      window = @current.window
      this.updateLocation(window, @current.url)
      @focus(window)
      if @current.pushState || was.pushState
        # Created with pushState/replaceState, send popstate event if navigating
        # within same host.
        oldHost = URL.parse(was.url).host
        newHost = URL.parse(@current.url).host
        if oldHost == newHost
          event = window.document.createEvent("HTMLEvents")
          event.initEvent("popstate", false, false)
          event.state = @current.pushState
          window._eventLoop.dispatch(window, event)
      else if hashChange(was, @current.url)
        event = window.document.createEvent("HTMLEvents")
        event.initEvent("hashchange", true, false)
        window._eventLoop.dispatch(window, event)
    return

  # This method is available from Location.
  @prototype.__defineGetter__ "length", ->
    entry = @first
    length = 0
    while entry
      ++length
      entry = entry.next
    return length

  # This method is available from Location.
  pushState: (state, title, url)->
    url = HTML.resourceLoader.resolve(@current.window.document, url)
    # TODO: check same origin
    @addEntry(@current.window, url, state || {})
    return

  # This method is available from Location.
  replaceState: (state, title, url)->
    url = HTML.resourceLoader.resolve(@current.window.document, url)
    # TODO: check same origin
    @replaceEntry(@current.window, url, state || {})
    return

  # This method is available from Location.
  @prototype.__defineGetter__ "state", ->
    if @current.pushState
      return @current.pushState



# Returns true if the hash portion of the URL changed between the history entry
# (entry) and the new URL we want to inspect (url).
hashChange = (entry, url)->
  return false unless entry
  first = URL.parse(entry.url)
  second = URL.parse(url)
  return first.host.toLowerCase() == second.host.toLowerCase() &&
         first.pathname == second.pathname &&
         first.query == second.query 


# DOM Location object
class Location
  constructor: (@history, @url)->

  assign: (url)->
    @history.assign(url)

  replace: (url)->
    @history.replace(url)

  reload: (force)->
    @history.replace(@url)

  toString: ->
    return @url

  # Setting any of the properties creates a new URL and navigates there
  for prop in ["hash", "host", "pathname", "port", "protocol", "search"]
    do (prop)=>
      @prototype.__defineGetter__ prop, ->
        return URL.parse(@url)[prop] || ""
      @prototype.__defineSetter__ prop, (value)->
        newUrl = URL.parse(@url)
        newUrl[prop] = value
        @history.assign(URL.format(newUrl))

  @prototype.__defineGetter__ "hostname", ->
    return URL.parse(@url).hostname
  @prototype.__defineSetter__ "hostname", (hostname)->
    newUrl = URL.parse(@url)
    if newUrl.port
      newUrl.host = "#{hostname}:#{newUrl.port}"
    else
      newUrl.host = hostname
    @history.assign(URL.format(newUrl))

  @prototype.__defineGetter__ "href", ->
    return URL.parse(@url).href
  @prototype.__defineSetter__ "href", (href)->
    @history.assign(URL.format(href))


module.exports = createHistory

