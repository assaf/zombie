# Window history and location.
jsdom = require("jsdom")
http = require("http")
URL = require("url")

# ## window.history
#
# Represents window.history.
class History
  constructor: (browser, window)->
    stack = []
    index = -1
    history = @
    cookies = browser.cookies
    # ### history.forward amount
    @forward = -> @go(1)
    # ### history.back amount
    @back = -> @go(-1)
    # ### history.go amount
    @go = (amount)->
      new_index = index + amount
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
      return
    # Number of states/URLs in the history.
    @__defineGetter__ "length", -> stack.length

    # ### history.pushState state, title, url
    #
    # Push new state to the stack, do not reload
    @pushState = (state, title, url)->
      entry = stack[index] if index >= 0
      url = URL.resolve(entry, url) if entry
      stack[++index] = { state: state, title: title, url: URL.parse(url.toString()), pop: true }
    # ### history.replaceState state, title, url
    #
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
      if URL.format(url) != URL.format(old)
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
      resource @_location
    # Form submission. Makes request and loads response in the background.
    #
    # url -- Same as form action, can be relative to current document
    # method -- Method to use, defaults to GET
    # data -- Form valuesa
    # enctype -- Encoding type, or use default
    @_submit = (url, method, data, enctype)->
      url = URL.resolve(URL.format(@_location), url)
      url = URL.parse(url)
      # Add location to stack, also clears any forward history.
      stack = stack[0..index]
      stack[++index] = { url: url }
      resource url, method, data, enctype

    # Make a request to external resource. We use this to fetch pages and
    # submit forms, see _loadPage and _submit.
    resource = (url, method = "GET", data, enctype)=>
      # Create new DOM Level 3 document, add features (load external resources,
      # etc) and associate it with current document. From this point on the
      # browser sees a new document, client register event handlers for
      # DOMContentLoaded/error.
      aug = jsdom.browserAugmentation(jsdom.dom.level3.html)
      document = new aug.HTMLDocument(url: URL.format(url), deferClose: true)
      jsdom.applyDocumentFeatures document
      window.document = document
      # HTTP request, nothing fancy.
      client = http.createClient(url.port || 80, url.hostname)
      headers = { "host": url.hostname }
      if method == "GET"
        url.search = URL.resolve(url, { query: data }).split("?")[1]
      else
        body = URL.format({ query: data }).substring(1)
        headers["content-type"] = enctype || "application/x-www-form-urlencoded"
        headers["content-length"] = body.length
      headers["cookie"] = cookies._header(url)
      path = url.pathname + (url.search || "")
      window.request (done)=>
        request = client.request(method, path, headers)
        client.on "error", (err)->
          console.error "Error requesting #{URL.format(url)}", error
          event = document.createEvent("HTMLEvents")
          event.initEvent "error", true, false
          document.dispatchEvent event
        request.on "response", (response)->
          response.setEncoding "utf8"
          body = ""
          response.on "data", (chunk)-> body += chunk
          response.on "end", ->
            browser.response = [response.statusCode, response.headers, body]
            if response.statusCode == 200
              cookies._update url, response.headers["set-cookie"]
              document.open()
              document.write body
              document.close()
              error = "Could not parse document at #{URL.format(url)}" unless document.documentElement
            else
              error = "Could not load document at #{URL.format(url)}, got #{response.statusCode}"
            # onerror is the only reliable way we have to notify the
            # application.
            if error
              console.error error
              event = document.createEvent("HTMLEvents")
              event.initEvent "error", true, false
              document.dispatchEvent event
            done()
        request.end body, "utf8"

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


# ## window.location
#
# Represents window.location and document.location.
class Location
  constructor: (history, @_url)->
    # ### location.assign url
    @assign = (url)-> history._assign url
    # ### location.replace url
    @replace = (url)-> history._replace url
    # ### location.reload force?
    @reload = (force)-> history._loadPage(force)
    # ### location.toString() => String
    @toString = -> URL.format(@_url)
    # ### location.href => String
    @__defineGetter__ "href", -> @_url?.href
    # ### location.href = url
    @__defineSetter__ "href", (url)-> history._assign url
    # Getter/setter for location parts.
    for prop in ["hash", "host", "hostname", "pathname", "port", "protocol", "search"]
      @__defineGetter__ prop, -> @_url?[prop]
      @__defineSetter__ prop, (value)->
        new_url = URL.parse(@_url?.href)
        new_url[prop] = value
        history._assign URL.format(new_url)

# ## document.location
# document.location is same as window.location
jsdom.dom.level3.core.HTMLDocument.prototype.__defineGetter__ "location", -> @parentWindow.location


# Attach Location/History to window: creates new history and adds
# location/history accessors.
exports.attach = (browser, window)->
  history = new History(browser, window)
  window.__defineGetter__ "history", -> history
  window.__defineSetter__ "history", (history)-> # runInNewContext needs this
  window.__defineGetter__ "location", => history._location
  window.__defineSetter__ "location", (url)=> history._assign url
