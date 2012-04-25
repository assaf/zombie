# Window history and location.
util = require("util")
JSDOM = require("jsdom")
HTML = JSDOM.dom.level3.html
URL = require("url")


# History entry. Consists of:
# - state -- As provided by pushState/replaceState
# - title -- As provided by pushState/replaceState
# - pop -- True if added using pushState/replaceState
# - url -- URL object of current location
# - location -- Location object
class Entry
  constructor: (@history, url, options)->
    if options
      @state = options.state
      @title = options.title
      @pop = !!options.pop
    @update url

  update: (url)->
    @url = URL.parse(URL.format(url))
    @location = new Location(@history, @url)


# ## window.history
#
# Represents window.history.
class History
  constructor: (window)->
    @_apply window
    # History is a stack of Entry objects.
    @_stack = []
    @_index = -1

  # Apply to window.
  _apply: (@_window)->
    @_browser = @_window.browser
    # Add Location/History to window.
    Object.defineProperty @_window, "location",
      get: =>
        return @_stack[@_index]?.location || new Location(this, {})
      set: (url)=>
        @_assign @_resolve(url)

  # Called when we switch to a new page with the URL of the old page.
  _pageChanged: (was)->
    url = @_stack[@_index]?.url
    if !was || was.host != url.host || was.pathname != url.pathname || was.query != url.query
      # We're on a different site or different page, load it
      @_resource url
    else if was.hash != url.hash
      # Hash changed. Do not reload page, but do send hashchange
      evt = @_window.document.createEvent("HTMLEvents")
      evt.initEvent "hashchange", true, false
      @_browser.dispatchEvent @_window, evt
    else
      # Load new page for now (but later on use caching).
      @_resource url

  # Make a request to external resource. We use this to fetch pages and
  # submit forms, see _loadPage and _submit.
  _resource: (url, method, data, headers)->
    method = (method || "GET").toUpperCase()
    unless url.protocol == "file:" || (url.protocol && url.hostname)
      throw new Error("Cannot load resource: #{URL.format(url)}")

    # If the browser has a new window, use it. If a document was already
    # loaded into that window it would have state information we don't want
    # (e.g. window.$) so open a new window.
    if @_window.top == @_window.parent && @_window.document
      newWindow = @_browser.open(history: this)
      @_apply newWindow

    # Create new DOM Level 3 document, add features (load external
    # resources, etc) and associate it with current document. From this
    # point on the browser sees a new document, client register event
    # handler for DOMContentLoaded/error.
    options =
      deferClose: false
      features:
        QuerySelector: true
        MutationEvents: "2.0"
        ProcessExternalResources: []
        FetchExternalResources: ["frame"]
      parser: @_browser.htmlParser
      url: URL.format(url)
    if @_browser.runScripts
      options.features.ProcessExternalResources.push "script"
      options.features.FetchExternalResources.push "script"
    if @_browser.loadCSS
      options.features.FetchExternalResources.push "css"
    document = JSDOM.jsdom(null, HTML, options)
    @_window.document = document
    document.window = document.parentWindow = @_window

    headers = if headers then JSON.parse(JSON.stringify(headers)) else {}
    referer = @_browser.referer || @_stack[@_index-1]?.url?.href
    headers["referer"] = referer if referer

    if credentials = @_browser.credentials
      switch credentials.scheme.toLowerCase()
        when "basic"
          base64 = new Buffer(credentials.user + ":" + credentials.password).toString("base64")
          headers["authorization"] = "Basic #{base64}"
        when "bearer"
          headers["authorization"] = "Bearer #{credentials.token}"
        when "oauth"
          headers["authorization"] = "OAuth #{credentials.token}"
    
    @_browser.resources.request method, url, data, headers, (error, response)=>
      if error
        document.write "<html><body>#{error}</body></html>"
        document.close()
        @_browser.emit "error", error
      else
        @_browser.response = [response.statusCode, response.headers, response.body]
        @_stack[@_index].update response.url
        if response.body
          html = response.body
        else
          html = "<html><body></body></html>"
        document.write html
        document.close()
        if document.documentElement
          @_browser.emit "loaded", @_browser
        else
          error = "Could not parse document at #{URL.format(url)}"

  # ### history.forward()
  forward: -> @go(1)

  # ### history.back()
  back: -> @go(-1)

  # ### history.go(amount)
  go: (amount)->
    was = @_stack[@_index]?.url
    new_index = @_index + amount
    new_index = 0 if new_index < 0
    if @_stack.length > 0 && new_index >= @_stack.length
      new_index = @_stack.length - 1
    if new_index != @_index && entry = @_stack[new_index]
      @_index = new_index
      if entry.pop
        if @_window.document
          # Created with pushState/replaceState, send popstate event
          evt = @_window.document.createEvent("HTMLEvents")
          evt.initEvent "popstate", false, false
          evt.state = entry.state
          @_browser.dispatchEvent @_window, evt
        # Do not load different page unless we're on a different host
        if was.host != @_stack[@_index]?.url?.host
          @_resource @_stack[@_index].url
      else
        @_pageChanged was
    return
 
  # ### history.length => Number
  #
  # Number of states/URLs in the history.
  @prototype.__defineGetter__ "length", ->
    return @_stack.length

  # ### history.pushState(state, title, url)
  #
  # Push new state to the stack, do not reload
  pushState: (state, title, url)->
    url = @_resolve(url)
    @_stack[++@_index] = new Entry(this, url, { state: state, title: title, pop: true })

  # ### history.replaceState(state, title, url)
  #
  # Replace existing state in the stack, do not reload
  replaceState: (state, title, url)->
    @_index = 0 if @_index < 0
    url = @_resolve(url)
    @_stack[@_index] = new Entry(this, url, { state: state, title: title, pop: true })

  # Resolve URL based on current page URL.
  _resolve: (url)->
    if url
      return URL.resolve(@_stack[@_index]?.url, url)
    else # Yes, this could happen
      return @_stack[@_index]?.url

  # Location uses this to move to a new URL.
  _assign: (url)->
    url = @_resolve(url)
    was = @_stack[@_index]?.url # before we destroy stack
    @_stack = @_stack[0..@_index]
    @_stack[++@_index] = new Entry(this, url)
    @_pageChanged was

  # Location uses this to load new page without changing history.
  _replace: (url)->
    url = @_resolve(url)
    was = @_stack[@_index]?.url # before we destroy stack
    @_index = 0 if @_index < 0
    @_stack[@_index] = new Entry(this, url)
    @_pageChanged was

  # Location uses this to force a reload (location.reload), history uses this
  # whenever we switch to a different page and need to load it.
  _loadPage: (force)->
    @_resource @_stack[@_index].url if @_stack[@_index]
  
  # Form submission. Makes request and loads response in the background.
  #
  # * url -- Same as form action, can be relative to current document
  # * method -- Method to use, defaults to GET
  # * data -- Form valuesa
  # * enctype -- Encoding type, or use default
  _submit: (url, method, data, enctype)->
    headers = { "content-type": enctype || "application/x-www-form-urlencoded" }
    @_stack = @_stack[0..@_index]
    url = @_resolve(url)
    @_stack[++@_index] = new Entry(this, url)
    @_resource @_stack[@_index].url, method, data, headers

  # Used to dump state to console (debuggin)
  dump: ->
    dump = []
    for i, entry of @_stack
      i = Number(i)
      line = if i == @_index then "#{i + 1}: " else "#{i + 1}. "
      line += URL.format(entry.url)
      line += " state: " + util.inspect(entry.state) if entry.state
      dump.push line
    dump

  # browser.saveHistory uses this
  save: ->
    serialized = []
    for i, entry of @_stack
      line = URL.format(entry.url)
      line += " #{JSON.stringify(entry.state)}" if entry.pop
      serialized.push line
    return serialized.join("\n") + "\n"

  # browser.loadHistory uses this
  load: (serialized) ->
    for line in serialized.split(/\n+/)
      line = line.trim()
      continue if line[0] == "#" || line == ""
      [url, state] = line.split(/\s/)
      options = state && { state: JSON.parse(state), title: null, pop: true }
      @_stack[++@_index] = new Entry(this, url, state)


# ## window.location
#
# Represents window.location and document.location.
class Location
  constructor: (@_history, @_url)->

  # ### location.assign(url)
  assign: (newUrl)->
    @_history._assign newUrl

  # ### location.replace(url)
  replace: (newUrl)->
    @_history._replace newUrl

  # ### location.reload(force?)
  reload: (force)->
    @_history._loadPage(force)

  # ### location.toString() => String
  toString: ->
    return URL.format(@_url)

  # ### location.href => String
  @prototype.__defineGetter__ "href", ->
    return @_url?.href

  # ### location.href = url
  @prototype.__defineSetter__ "href", (new_url)->
    @_history._assign new_url

  # Getter/setter for location parts.
  for prop in ["hash", "host", "hostname", "pathname", "port", "protocol", "search"]
    do (prop)=>
      @prototype.__defineGetter__ prop, ->
        @_url?[prop] || ""
      @prototype.__defineSetter__ prop, (value)->
        newUrl = URL.parse(@_url?.href)
        newUrl[prop] = value
        @_history._assign URL.format(newUrl)


# ## document.location => Location
#
# document.location is same as window.location
HTML.HTMLDocument.prototype.__defineGetter__ "location", ->
  @parentWindow.location
HTML.HTMLDocument.prototype.__defineSetter__ "location", (url)->
  @parentWindow.location = url


module.exports = History
