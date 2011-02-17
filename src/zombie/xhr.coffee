# window.XMLHttpRequest
core = require("jsdom").dom.level3.core
http = require("http")
URL = require("url")


# Additional error codes defines for XHR and not in JSDOM.
core.SECURITY_ERR = 18
core.NETWORK_ERR = 19
core.ABORT_ERR = 20

XMLHttpRequest = (window)->
  # Fire onreadystatechange event
  stateChanged = (state)=>
    @__defineGetter__ "readyState", -> state
    if @onreadystatechange
      # Since we want to wait on these events, put them in the event loop.
      window.perform (done)=>
        process.nextTick =>
          try
            @onreadystatechange.call(@)
          catch error
            evt = window.document.createEvent("HTMLEvents")
            evt.initEvent "error", true, false
            evt.error = error
            window.dispatchEvent evt
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
    @setRequestHeader = @send = -> throw new core.DOMException(core.INVALID_STATE_ERR,  "Invalid state")
    @getResponseHeader = @getAllResponseHeader = ->
    # Open method.
    @open = (method, url, async, user, password)->
      method = method.toUpperCase()
      throw new core.DOMException(core.SECURITY_ERR, "Unsupported HTTP method") if /^(CONNECT|TRACE|TRACK)$/.test(method)
      throw new core.DOMException(core.SYNTAX_ERR, "Unsupported HTTP method") unless /^(DELETE|GET|HEAD|OPTIONS|POST|PUT)$/.test(method)
      url = URL.parse(URL.resolve(window.location.href, url))
      url.hostname ||= window.location.hostname
      url.host = "#{url.hostname}:#{url.port}"
      url.hash = null
      throw new core.DOMException(core.SECURITY_ERR, "Cannot make request to different domain") unless url.host == window.location.host
      throw new core.DOMException(core.NOT_SUPPORTED_ERR, "Only HTTP protocol supported") unless url.protocol == "http:"
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
          @_error = new core.DOMException(core.ABORT_ERR, "Request aborted")
          stateChanged 4
          reset()

        # Make the actual request: called again when dealing with a redirect.
        window.resources.request method, url, data, headers, (error, response)=>
          if error
            console.error "XHR error", error
            @_error = new core.DOMException(core.NETWORK_ERR, error.message)
            stateChanged 4
            reset()
          else
            # At this state, allow retrieving of headers and status code.
            @getResponseHeader = (header)-> response.headers[header.toLowerCase()]
            @getAllResponseHeader = -> response.headers
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
