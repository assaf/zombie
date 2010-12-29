# Window history and location.
http = require("http")
jsdom = require("jsdom")
html = jsdom.dom.level3.html
qs = require("querystring")
URL = require("url")
util = require("util")


# History entry. Consists of:
# - state -- As provided by pushState/replaceState
# - title -- As provided by pushState/replaceState
# - pop -- True if added using pushState/replaceState
# - url -- URL object of current location
# - location -- Location object
class Entry
  constructor: (history, url, options)->
    @url = URL.parse(URL.format(url))
    @location = new Location(history, @url)
    if options
      @state = options.state
      @title = options.title
      @pop = !!options.pop


# ## window.history
#
# Represents window.history.
class History
  constructor: (browser)->
    # History is a stack of Entry objects.
    stack = []
    index = -1

    # Called when we switch to a new page with the URL of the old page.
    pageChanged = (was)=>
      url = stack[index]?.url
      if !was || was.host != url.host || was.pathname != url.pathname || was.query != url.query
        # We're on a different site or different page, load it
        resource url
      else if was.hash != url.hash
        # Hash changed. Do not reload page, but do send hashchange
        evt = browser.document.createEvent("HTMLEvents")
        evt.initEvent "hashchange", true, false
        browser.window.dispatchEvent evt
    
    # Make a request to external resource. We use this to fetch pages and
    # submit forms, see _loadPage and _submit.
    resource = (url, method, data, enctype)=>
      method = (method || "GET").toUpperCase()
      throw new Error("Cannot load resource: #{URL.format(url)}") unless url.protocol && url.hostname
      window = browser.window
      window = browser.open() if browser.window.document
      # Create new DOM Level 3 document, add features (load external
      # resources, etc) and associate it with current document. From this
      # point on the browser sees a new document, client register event
      # handler for DOMContentLoaded/error.
      aug = jsdom.browserAugmentation(html)
      document = new aug.HTMLDocument(url: URL.format(url), deferClose: false)
      jsdom.applyDocumentFeatures document
      document.write = html.HTMLDocument.prototype._write
      document.fixQueue()
      window.document = document

      # Make the actual request: called again when dealing with a redirect.
      makeRequest = (url, method, data)=>
        headers = {}
        browser.cookies(url.hostname, url.pathname).addHeader headers
        if method == "GET" || method == "HEAD"
          url.search = "?" + qs.stringify(data) if data
          data = null
        else
          data = qs.stringify(data)
          headers["content-type"] = enctype || "application/x-www-form-urlencoded"
          headers["content-length"] = data.length

        window.request { url: URL.format(url), method: method, headers: headers, body: data }, (done)=>
          client = http.createClient(url.port || 80, url.hostname)
          path = url.pathname
          path = path + url.search if url.search
          headers.host = url.host
          request = client.request(method, path, headers)

          request.on "response", (response)=>
            response.setEncoding "utf8"
            body = ""
            response.on "data", (chunk)-> body += chunk
            response.on "end", =>
              browser.response = [response.statusCode, response.headers, body]
              done null, { status: response.statusCode, headers: response.headers, body: body }
              switch response.statusCode
                when 200
                  browser.cookies(url.hostname, url.pathname).update response.headers["set-cookie"]
                  document.open()
                  document.write body
                  document.close()
                  if document.documentElement
                    browser.emit "loaded", browser
                  else
                    error = "Could not parse document at #{URL.format(url)}"
                when 301, 302, 303, 307
                  redirect = URL.parse(URL.resolve(url, response.headers["location"]))
                  stack[index] = new Entry(this, redirect)
                  browser.emit "redirected", redirect
                  process.nextTick -> makeRequest redirect, "GET"
                else
                  error = "Could not load document at #{URL.format(url)}, got #{response.statusCode}"
                  document.open()
                  document.write error
                  document.close()
              # onerror is the only reliable way we have to notify the
              # application.
              if error
                event = document.createEvent("HTMLEvents")
                event.initEvent "error", true, false
                document.dispatchEvent event
                browser.emit "error", new Error(error)

          client.on "error", (error)->
            event = document.createEvent("HTMLEvents")
            event.initEvent "error", true, false
            document.dispatchEvent event
            browser.emit "error", new Error(error)
            done error
          request.end data, "utf8"
      makeRequest url, method, data

    # ### history.forward()
    @forward = -> @go(1)
    # ### history.back()
    @back = -> @go(-1)
    # ### history.go(amount)
    @go = (amount)->
      was = stack[index]?.url
      new_index = index + amount
      new_index = 0 if new_index < 0
      new_index = stack.length - 1 if stack.length > 0 && new_index >= stack.length
      if new_index != index && entry = stack[new_index]
        index = new_index
        if entry.pop
          if browser.document
            # Created with pushState/replaceState, send popstate event
            evt = browser.document.createEvent("HTMLEvents")
            evt.initEvent "popstate", false, false
            evt.state = entry.state
            browser.window.dispatchEvent evt
          # Do not load different page unless we're on a different host
          resource stack[index] if was.host != stack[index].host
        else
          pageChanged was
      return
    # ### history.length => Number
    #
    # Number of states/URLs in the history.
    @__defineGetter__ "length", -> stack.length

    # ### history.pushState(state, title, url)
    #
    # Push new state to the stack, do not reload
    @pushState = (state, title, url)->
      stack[++index] = new Entry(this, url, { state: state, title: title, pop: true })
    # ### history.replaceState(state, title, url)
    #
    # Replace existing state in the stack, do not reload
    @replaceState = (state, title, url)->
      index = 0 if index < 0
      stack[index] = new Entry(this, url, { state: state, title: title, pop: true })

    # Location uses this to move to a new URL.
    @_assign = (url)->
      was = stack[index]?.url # before we destroy stack
      stack = stack[0..index]
      stack[++index] = new Entry(this, url)
      pageChanged was
    # Location uses this to load new page without changing history.
    @_replace = (url)->
      was = stack[index]?.url # before we destroy stack
      index = 0 if index < 0
      stack[index] = new Entry(this, url)
      pageChanged was
    # Location uses this to force a reload (location.reload), history uses this
    # whenever we switch to a different page and need to load it.
    @_loadPage = (force)->
      resource stack[index].url if stack[index]
    # Form submission. Makes request and loads response in the background.
    #
    # * url -- Same as form action, can be relative to current document
    # * method -- Method to use, defaults to GET
    # * data -- Form valuesa
    # * enctype -- Encoding type, or use default
    @_submit = (url, method, data, enctype)->
      stack = stack[0..index]
      url = URL.resolve(stack[index]?.url, url)
      stack[++index] = new Entry(this, url)
      resource stack[index].url, method, data, enctype

    # Add Location/History to window.
    this.extend = (window)->
      window.__defineGetter__ "history", => this
      window.__defineGetter__ "location", => stack[index]?.location || new Location(this, {})
      window.__defineSetter__ "location", (url)=>
        @_assign URL.resolve(stack[index]?.url, url)

    this.dump = ->
      dump = []
      for i, entry of stack
        i = Number(i)
        line = if i == index then "#{i + 1}: " else "#{i + 1}. "
        line += URL.format(entry.url)
        line += " state: " + util.inspect(entry.state) if entry.state
        dump.push line
      dump


# ## window.location
#
# Represents window.location and document.location.
class Location
  constructor: (history, url)->
    # ### location.assign(url)
    @assign = (newUrl)-> history._assign newUrl
    # ### location.replace(url)
    @replace = (newUrl)-> history._replace newUrl
    # ### location.reload(force?)
    @reload = (force)-> history._loadPage(force)
    # ### location.toString() => String
    @toString = -> URL.format(url)
    # ### location.href => String
    @__defineGetter__ "href", -> url?.href
    # ### location.href = url
    @__defineSetter__ "href", (url)-> history._assign url
    # Getter/setter for location parts.
    for prop in ["hash", "host", "hostname", "pathname", "port", "protocol", "search"]
      do (prop)=>
        @__defineGetter__ prop, -> url?[prop]
        @__defineSetter__ prop, (value)->
          newUrl = URL.parse(url?.href)
          newUrl[prop] = value
          history._assign URL.format(newUrl)

# ## document.location => Location
#
# document.location is same as window.location
html.HTMLDocument.prototype.__defineGetter__ "location", -> @parentWindow.location


exports.use = (browser)->
  return new History(browser)
