JSDOM = require("jsdom")
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
        @_reload() if @window.location.host != entry.host
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
    url = URL.parse(url.toString())
    old = @_url # before we destroy stack
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
  _reload: (force)->
    if url = @_url
      browser = JSDOM.browserAugmentation(JSDOM.dom.level3.html)
      document = new browser.HTMLDocument()
      document._documentRoot = document._URL = URL.format(url)
      document.readyState = "loading"
      JSDOM.applyDocumentFeatures(document)
      @window.document = document
      loader = JSDOM.dom.level3.core.resourceLoader
      loader.download url, (err, data)->
        if err
          evt = document.createEvent("HTMLEvents")
          evt.initEvent "error", true, false
          document.dispatchEvent evt
        else
          document.open()
          document.write(data)
          document.close()
  _pageChanged: (old)->
    url = @_url
    if !old || old.host != url.host || old.pathname != url.pathname || old.query != url.query
      # We're on a different site or different page, load it
      @_reload()
    else if old.hash != url.hash
      # Hash changed. Do not reload page, but do send hashchange
      evt = @window.createEvent("HTMLEvents")
      evt.initEvent "hashchange", true, false
      @window.dispatchEvent evt
History.prototype.__defineGetter__ "_url", ->
  # Returns current URL (as object not string).
  entry = @stack[@index]
  entry?.url
History.prototype.__defineGetter__ "length", -> @stack.length


# Represents window.location and document.location.
class Location
  constructor: (@history)->
  assign: (url)-> @history._assign url
  replace: (url)-> @history._replace url
  reload: (force)-> @history._reload()
  toString: -> URL.format(@history.current)
Location.prototype.__defineGetter__ "href", -> @history._url?.href
Location.prototype.__defineSetter__ "href", (url)-> @history._assign url
for prop in ["hash", "host", "hostname", "pathname", "port", "protocol", "search"]
  Location.prototype.__defineGetter__ prop, -> @history._url?[prop]
  Location.prototype.__defineSetter__ prop, (value)->
    url = URL.parse(@current.toString())
    url[prop] = value
    @history._assign url

exports.apply = (window)->
  history = new History(window)
  window.__defineGetter__ "history", -> history
  window.__defineSetter__ "history", (history)-> # runInNewContext needs this
  location = new Location(history)
  window.__defineGetter__ "location", => location
  window.__defineSetter__ "location", (url)=>
    history._assign url
# document.location is same as window.location
JSDOM.dom.level3.core.HTMLDocument.prototype.__defineGetter__ "location", => @ownerWindow.location
