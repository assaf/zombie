# Window history and location.
util    = require("util")
JSDOM   = require("jsdom")
HTML    = JSDOM.dom.level3.html
Scripts = require("./scripts")
URL     = require("url")


ABOUT_BLANK = URL.parse("about:blank")


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
    @_use window
    # History is a stack of Entry objects.
    @_stack = []
    @_index = 0

  # Apply to window.
  _use: (window)->
    @_window = window
    @_browser = @_window.browser
    # Add Location/History to window.
    Object.defineProperty @_window, "location",
      get: =>
        return @_stack[@_index]?.location || new Location(this, ABOUT_BLANK)
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
    # Let's handle the specifics of each protocol
    switch url.protocol
      when "about:"
        # Blank document. We're done.
        @_createDocument(@_window, ABOUT_BLANK)
        @_stack[@_index].update url
        @_browser.emit "loaded", @_browser
      when "javascript:"
        @_createDocument(@_window, ABOUT_BLANK)
        # This means evaluate the expression ... do not update location but
        # start with empty page.
        unless @_stack[@_index]
          @_stack[@_index].update ABOUT_BLANK
        try
          @_window._evaluate url.pathname, "javascript:"
          @_browser.emit "loaded", @_browser
        catch error
          @_browser.emit "error", error
      when "http:", "https:", "file:"
        headers = if headers then JSON.parse(JSON.stringify(headers)) else {}
        referer = @_stack[@_index-1]?.url?.href || @_browser.referer
        headers["referer"] = referer if referer

        Path = require("path")
        if url.protocol == "file:"
          url = URL.format(protocol: "file:", host: "", pathname: "/#{url.hostname}#{url.pathname}")

        # Proceeed to load resource ...
        method = (method || "GET").toUpperCase()
        @_browser.resources.request method, url, data, headers, (error, response)=>
          document = @_createDocument(@_window, response.url)
          if error
            document.open()
            document.write error.message
            document.close()
            @_browser.emit "error", error
          else
            @_browser.response = [response.statusCode, response.headers, response.body]
            url = URL.parse(response.url)
            @_stack[@_index].update url
            # For responses that contain a non-empty body, load it.  Otherwise, we
            # already have an empty document in there courtesy of JSDOM.
            if response.body
              document.open()
              document.write response.body
              document.close()

            if url.hash
              evt = @_window.document.createEvent("HTMLEvents")
              evt.initEvent "hashchange", true, false
              @_browser.dispatchEvent @_window, evt

            # Error on any response that's not 2xx, or if we're not smart enough to
            # process the content and generate an HTML DOM tree from it.
            if response.statusCode >= 400
              @_browser.emit "error", new Error("Server returned status code #{response.statusCode}")
            else if document.documentElement
              @_browser.emit "loaded", @_browser
            else
              @_browser.emit "error", new Error("Could not parse document at #{URL.format(url)}")
        
      else # but not any other protocol for now
        throw new Error("Cannot load resource: #{URL.format(url)}")

  # Create an empty document, set it up and return it.
  _createDocument: (window, url)->
    # Create new DOM Level 3 document, add features (load external resources,
    # etc) and associate it with current document. From this point on the
    # browser sees a new document, client register event handler for
    # DOMContentLoaded/error.
    jsdom_opts =
      deferClose: true
      features:
        MutationEvents:           "2.0"
        ProcessExternalResources: []
        FetchExternalResources:   ["iframe"]
      parser: @_browser.htmlParser
      url:    URL.format(url)

    # require("html5").HTML5
    if @_browser.runScripts
      jsdom_opts.features.ProcessExternalResources.push "script"
      jsdom_opts.features.FetchExternalResources.push "script"
    if @_browser.loadCSS
      jsdom_opts.features.FetchExternalResources.push "css"

    document = JSDOM.jsdom(null, HTML, jsdom_opts)

    # Add support for running in-line scripts
    if @_browser.runScripts
      Scripts.addInlineScriptSupport document

    # Associate window and document
    window.document = document
    document.window = document.parentWindow = window
    # Set this to the same user agent that's loading this page
    window.navigator.userAgent = @_browser.userAgent

    # Fire onload event on window.
    document.addEventListener "DOMContentLoaded", (event)=>
      onload = document.createEvent("HTMLEvents")
      onload.initEvent "load", false, false
      window.dispatchEvent onload

    return document



  # ### history.forward()
  forward: ->
    @go(1)

  # ### history.back()
  back: ->
    @go(-1)

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
        # Do not load different page unless we're on a different host
        if was.host != @_stack[@_index]?.url?.host
          @_resource @_stack[@_index].url
        else
          # Created with pushState/replaceState, send popstate event
          popstate = @_window.document.createEvent("HTMLEvents")
          popstate.initEvent "popstate", false, false
          popstate.state = entry.state
          @_browser.dispatchEvent @_window, popstate
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
    @_advance()
    @_stack[@_index] = new Entry(this, url, { state: state, title: title, pop: true })

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
    @_advance()
    @_stack[@_index] = new Entry(this, url)
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
    @_advance()
    @_stack[@_index] = new Entry(this, url)
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
      @_advance()
      @_stack[@_index] = new Entry(this, url, state)

  # Advance to the next position in history. Used when opening a new page, but
  # smart enough to not count about:blank in history.
  _advance: ->
    current = @_stack[@_index]
    if current && ~["http:", "https:", "file:"].indexOf(current.url.protocol)
      ++@_index


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
  # Avoids infinite loop setting document location during iframe creation
  @parentWindow.location = url if @_parentWindow


module.exports = History
