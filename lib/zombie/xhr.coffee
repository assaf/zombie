# window.XMLHttpRequest
html = require("jsdom").dom.level3.html
http = require("http")
URL = require("url")
{ raise } = require("./helpers")


# Additional error codes defines for XHR and not in JSDOM.
html.SECURITY_ERR = 18
html.NETWORK_ERR = 19
html.ABORT_ERR = 20

XMLHttpRequest = (window)->
  # Fire onreadystatechange event
  stateChanged = (state)=>
    @__defineGetter__ "readyState", -> state
    if @onreadystatechange
      # Since we want to wait on these events, put them in the event loop.
      window.browser._eventloop.perform (done)=>
        process.nextTick =>
          try
            @onreadystatechange.call(@)
          catch error
            raise element: window.document, from: __filename, scope: "XHR", error: error
          finally
            done()
  # Bring XHR to initial state (open/abort).
  reset = =>
    # Switch back to unsent state
    @__defineGetter__ "readyState", -> 0
    @__defineGetter__ "status", -> 0
    @__defineGetter__ "statusText", ->
    # These methods not applicable yet.
    @abort = -> # do nothing
    @setRequestHeader = @send = -> throw new html.DOMException(html.INVALID_STATE_ERR,  "Invalid state")
    @getResponseHeader = @getAllResponseHeaders = ->
    # Open method.
    @open = (method, url, async, user, password)->
      method = method.toUpperCase()
      throw new html.DOMException(html.SECURITY_ERR, "Unsupported HTTP method") if /^(CONNECT|TRACE|TRACK)$/.test(method)
      throw new html.DOMException(html.SYNTAX_ERR, "Unsupported HTTP method") unless /^(DELETE|GET|HEAD|OPTIONS|POST|PUT)$/.test(method)
      url = URL.parse(URL.resolve(window.location.href, url))
      url.hostname ||= window.location.hostname
      url.host = if url.port then "#{url.hostname}:#{url.port}" else url.hostname
      url.hash = null
      throw new html.DOMException(html.SECURITY_ERR, "Cannot make request to different domain") unless url.host == window.location.host
      throw new html.DOMException(html.NOT_SUPPORTED_ERR, "Only HTTP/S protocol supported") unless url.protocol in ["http:", "https:"]
      [user, password] = url.auth.split(":") if url.auth

      # Aborting open request.
      @_error = null
      aborted = false
      @abort = ->
        aborted = true
        reset()

      headers = {}
      @setRequestHeader = (header, value)-> headers[header.toString().toLowerCase()] = value.toString()
      # Allow calling send method.
      @send = (data)->
        # Aborting request in progress.
        @abort = ->
          aborted = true
          @_error = new html.DOMException(html.ABORT_ERR, "Request aborted")
          stateChanged 4
          reset()

        # Make the actual request: called again when dealing with a redirect.
        window.browser.resources.request method, url, data, headers, (error, response)=>
          if error
            console.error "XHR error", error
            @_error = new html.DOMException(html.NETWORK_ERR, error.message)
            stateChanged 4
            reset()
          else
            # At this state, allow retrieving of headers and status code.
            @getResponseHeader = (header)-> response.headers[header.toLowerCase()]
            @getAllResponseHeaders = ->
              ###
              XHR's getAllResponseHeaders, against all reason, returns a multi-line string.
              See http://www.w3.org/TR/XMLHttpRequest/#the-getallresponseheaders-method
              ###
              headerStrings = for header, value of response.headers
                "#{header}: #{value}"
              return headerStrings.join("\n")
            @__defineGetter__ "status", -> response.statusCode
            @__defineGetter__ "statusText", -> response.statusText
            stateChanged 2
            unless aborted
              @__defineGetter__ "responseText", -> response.body
              @__defineGetter__ "responseXML", -> # not implemented
              stateChanged 4

      # Calling open at this point aborts the ongoing request, resets the
      # state and starts a new request going
      @open = (method, url, async, user, password)->
        @abort()
        @open method, url, async, user, password

      # Successfully completed open method
      stateChanged 1
  reset()
  return

XMLHttpRequest.UNSENT = 0
XMLHttpRequest.OPENED = 1
XMLHttpRequest.HEADERS_RECEIVED = 2
XMLHttpRequest.LOADING = 3
XMLHttpRequest.DONE = 4


exports.use = ->
  # Add XHR constructor to window.
  extend = (window)->
    window.XMLHttpRequest = -> XMLHttpRequest.call this, window
  return extend: extend
