jsdom = require("jsdom")
URL = require("url")

# Represents window.history.
class History
  constructor: (@window)->
    @stack = []
    @index = -1
    history = @
  forward: -> @go(1)
  back: -> @go(-1)
  go: (steps)->
    index = @index + steps
    index = 0 if index < 0
    index = @stack.length - 1 if @stack.length > 0 && index >= @stack.length
    old = @_url
    if index != @index && entry = @stack[index]
      @index = index
      if entry.pop
        if @window.document
          # Created with pushState/replaceState, send popstate event
          evt = @window.document.createEvent("HTMLEvents")
          evt.initEvent "popstate", false, false
          evt.state = entry.state
          @window.dispatchEvent evt
        # Do not load different page unless we're on a different host
        @_loadPage() if @window.location.host != entry.host
      else
        @_pageChanged old
  # Push new state to the stack, do not reload
  pushState: (state, title, url)->
    entry = @stack[@index]
    url = URL.resolve(entry, url) if entry
    @stack[++@index] = { state: state, title: title, url: URL.parse(url.toString()), pop: true }
  # Replace existing state in the stack, do not reload
  replaceState: (state, title, url)->
    @index = 0 if @index < 0
    entry = @stack[@index]
    url = URL.resolve(entry, url) if entry
    @stack[@index] = { state: state, title: title, url: URL.parse(url.toString()), pop: true }
  # Location uses this to move to a new URL.
  _assign: (url)->
    old = @_url # before we destroy stack
    url = URL.resolve(URL.format(old), url) if old
    url = URL.parse(url.toString())
    @stack = @stack[0..@index]
    @stack[++@index] = { url: url }
    @_pageChanged old
  # Location uses this to load new page without changing history.
  _replace: (url)->
    @index = 0 if @index < 0
    url = URL.parse(url)
    old = @_url # before we destroy stack
    @stack[@index] = { url: url }
    @_pageChanged old
  # Location uses this to force a reload (location.reload), history uses this
  # whenever we switch to a different page and need to load it.
  _loadPage: (force)->
    if url = @_url
      browser = jsdom.browserAugmentation(jsdom.dom.level3.html)
      document = new browser.HTMLDocument()
      document._documentRoot = document._URL = URL.format(url)
      document.readyState = "loading"
      jsdom.applyDocumentFeatures(document)
      @window.document = document
      loader = jsdom.dom.level3.core.resourceLoader
      loader.download url, (err, data)=>
        if err
          evt = document.createEvent("HTMLEvents")
          evt.initEvent "error", true, false
          document.dispatchEvent evt
        else
          document.open()
          document.write(data)
          document.close()
          @window.enhance document
  # Called when we switch to a new page with the URL of the old page.
  _pageChanged: (old)->
    url = @_url
    if !old || old.host != url.host || old.pathname != url.pathname || old.query != url.query
      # We're on a different site or different page, load it
      @_loadPage()
    else if old.hash != url.hash
      # Hash changed. Do not reload page, but do send hashchange
      evt = @window.document.createEvent("HTMLEvents")
      evt.initEvent "hashchange", true, false
      @window.dispatchEvent evt
# Returns current URL (as object not string).
History.prototype.__defineGetter__ "_url", ->
  entry = @stack[@index]
  entry?.url
# Number of states/URLs in the history.
History.prototype.__defineGetter__ "length", -> @stack.length


# Represents window.location and document.location.
class Location
  constructor: (@history)->
  assign: (url)-> @history._assign url
  replace: (url)-> @history._replace url
  reload: (force)-> @history._loadPage(force)
  toString: -> URL.format(@history._url)
# Getter/setter for full URL.
Location.prototype.__defineGetter__ "href", -> @history._url?.href
Location.prototype.__defineSetter__ "href", (url)-> @history._assign url
# Getter/setter for location parts.
for prop in ["hash", "host", "hostname", "pathname", "port", "protocol", "search"]
  Location.prototype.__defineGetter__ prop, -> @history._url?[prop]
  Location.prototype.__defineSetter__ prop, (value)->
    url = URL.parse(@history._url?.href)
    url[prop] = value
    @history._assign URL.format(url)

# document.location is same as window.location
jsdom.dom.level3.core.HTMLDocument.prototype.__defineGetter__ "location", => @ownerWindow.location

# Apply Location/History to window: creates new history and adds
# location/history accessors.
exports.apply = (window)->
  history = new History(window)
  window.__defineGetter__ "history", -> history
  window.__defineSetter__ "history", (history)-> # runInNewContext needs this
  location = new Location(history)
  window.__defineGetter__ "location", => location
  window.__defineSetter__ "location", (url)=>
    history._assign url
