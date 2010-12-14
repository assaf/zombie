jsdom = require("jsdom")
http = require("http")
URL = require("url")

# Represents window.history.
class History
  constructor: (window)->
    stack = []
    index = -1
    history = @
    @forward = -> @go(1)
    @back = -> @go(-1)
    @go = (steps)->
      new_index = index + steps
      new_index = 0 if new_index < 0
      new_index = stack.length - 1 if stack.length > 0 && new_index >= stack.length
      old = @_location
      if new_index != index && entry = stack[new_index]
        index = new_index
        if entry.pop
          if window.document
            # Created with pushState/replaceState, send popstate event
            evt = window.document.createEvent("HTMLEvents")
            evt.initEvent "popstate", false, false
            evt.state = entry.state
            window.dispatchEvent evt
          # Do not load different page unless we're on a different host
          @_loadPage() if window.location.host != entry.host
        else
          pageChanged old
    # Number of states/URLs in the history.
    @__defineGetter__ "length", -> stack.length

    # Push new state to the stack, do not reload
    @pushState = (state, title, url)->
      entry = stack[index] if index >= 0
      url = URL.resolve(entry, url) if entry
      stack[++index] = { state: state, title: title, url: URL.parse(url.toString()), pop: true }
    # Replace existing state in the stack, do not reload
    @replaceState = (state, title, url)->
      index = 0 if index < 0
      entry = stack[index]
      url = URL.resolve(entry, url) if entry
      stack[index] = { state: state, title: title, url: URL.parse(url.toString()), pop: true }

    # Returns current URL (as object not string).
    @__defineGetter__ "_location", -> new Location(this, stack[index]?.url)
    # Location uses this to move to a new URL.
    @_assign = (url)->
      old = @_location # before we destroy stack
      url = URL.resolve(URL.format(old), url) if old
      url = URL.parse(url.toString())
      stack = stack[0..index]
      stack[++index] = { url: url }
      pageChanged old
    # Location uses this to load new page without changing history.
    @_replace = (url)->
      index = 0 if index < 0
      url = URL.parse(url)
      old = @_location # before we destroy stack
      stack[index] = { url: url }
      pageChanged old
    # Location uses this to force a reload (location.reload), history uses this
    # whenever we switch to a different page and need to load it.
    @_loadPage = (force)->
      if url = @_location
        aug = jsdom.browserAugmentation(jsdom.dom.level3.html)
        document = new aug.HTMLDocument(url: url.toString(), deferClose: true)
        jsdom.applyDocumentFeatures(document)
        window.document = document
        window.request (done)->
          jsdom.dom.level3.core.resourceLoader.download url, (err, data)=>
            if err
              evt = document.createEvent("HTMLEvents")
              evt.initEvent "error", true, false
              document.dispatchEvent evt
            else
              document.open()
              document.write data
              document.close()
            done()
    # Form submission. Makes request and loads response in the background.
    #
    # url -- Same as form action, can be relative to current document
    # method -- Method to use, defaults to GET
    # data -- Form valuesa
    # enctype -- Encoding type, or use default
    @_submit = (url, method = "GET", data, enctype)=>
      url = URL.resolve(URL.format(@_location), url)
      url = URL.parse(url)

      # Add location to stack.
      stack = stack[0..index]
      stack[++index] = { url: url }
      # Create new document and associate it with current window.
      aug = jsdom.browserAugmentation(jsdom.dom.level3.html)
      document = new aug.HTMLDocument(url: url.toString(), deferClose: true)
      window.document = document

      client = http.createClient(url.port || 80, url.hostname)
      headers = { "host": url.hostname, "content-type": enctype || "application/x-www-form-urlencoded" }
      if method == "GET"
        url.search = URL.resolve(url, { query: data }).split("?")[1]
      else
        body = URL.format({ query: data }).substring(1)
        headers["content-length"] = body.length
      path = url.pathname + (url.search || "")
      window.request (done)=>
        request = client.request(method, path, headers)
        request.on "response", (response)->
          response.setEncoding "utf8"
          data = ""
          response.on "data", (chunk)-> data += chunk
          response.on "end", ->
            document.open()
            document.write data
            document.close()
            unless document.documentElement
              console.error "Could not parse document at #{URL.format(url)}"
              event = document.createEvent("HTMLEvents")
              event.initEvent "error", true, false
              document.dispatchEvent event
            done()
        request.end body || "", "utf8"

    # Called when we switch to a new page with the URL of the old page.
    pageChanged = (old)=>
      url = @_location
      if !old || old.host != url.host || old.pathname != url.pathname || old.query != url.query
        # We're on a different site or different page, load it
        @_loadPage()
      else if old.hash != url.hash
        # Hash changed. Do not reload page, but do send hashchange
        evt = window.document.createEvent("HTMLEvents")
        evt.initEvent "hashchange", true, false
        window.dispatchEvent evt


# Represents window.location and document.location.
class Location
  constructor: (history, @_url)->
    @assign = (url)-> history._assign url
    @replace = (url)-> history._replace url
    @reload = (force)-> history._loadPage(force)
    @toString = -> URL.format(@_url)
    # Getter/setter for full URL.
    @__defineGetter__ "href", -> @_url?.href
    @__defineSetter__ "href", (url)-> history._assign url
    # Getter/setter for location parts.
    for prop in ["hash", "host", "hostname", "pathname", "port", "protocol", "search"]
      @__defineGetter__ prop, -> @_url?[prop]
      @__defineSetter__ prop, (value)->
        new_url = URL.parse(@_url?.href)
        new_url[prop] = value
        history._assign URL.format(new_url)

# document.location is same as window.location
jsdom.dom.level3.core.HTMLDocument.prototype.__defineGetter__ "location", => @ownerWindow.location


# Apply Location/History to window: creates new history and adds
# location/history accessors.
exports.apply = (window)->
  history = new History(window)
  window.__defineGetter__ "history", -> history
  window.__defineSetter__ "history", (history)-> # runInNewContext needs this
  window.__defineGetter__ "location", => history._location
  window.__defineSetter__ "location", (url)=> history._assign url
