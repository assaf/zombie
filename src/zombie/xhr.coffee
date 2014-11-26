# Implemenets XMLHttpRequest.
HTML      = require("jsdom").defaultLevel
Events    = require("jsdom").level(3, 'events')
URL       = require("url")
raise     = require("./scripts")


# Additional error codes defines for XHR and not in JSDOM.
HTML.SECURITY_ERR = 18
HTML.NETWORK_ERR = 19
HTML.ABORT_ERR = 20


class XMLHttpRequest extends Events.EventTarget
  constructor: (window)->
    @_window = window
    # Pending request
    @_pending     = null
    # Response headers
    @_responseHeaders = null
    @onreadystatechange = null
    @timeout      = 0
    @status       = null
    @statusText   = null
    @responseText = null
    @responseXML  = null

    # XHR events need the first to dispatch, the second to propagate up to window
    @_ownerDocument = window.document
    @_parentNode    = window

  # Aborts the request if it has already been sent.
  abort: ->
    # Tell any pending request it has been aborted.
    request = @_pending
    if request
      request.error ||= new HTML.DOMException(HTML.ABORT_ERR, "Request aborted")
      request.aborted = true
    # Change ready state, but do not call listener, this will happen when
    # pending request completes.
    @readyState = XMLHttpRequest.UNSENT


  # Returns all the response headers as a string, or null if no response has
  # been received. Note: For multipart requests, this returns the headers from
  # the current part of the request, not from the original channel.
  getAllResponseHeaders: (header)->
    if @_responseHeaders
      # XHR's getAllResponseHeaders, against all reason, returns a multi-line
      # string.  See http://www.w3.org/TR/XMLHttpRequest/#the-getallresponseheaders-method
      headerStrings = []
      for header, value of @_responseHeaders
        headerStrings.push("#{header}: #{value}")
      return headerStrings.join("\n")
    else
      return null

  # Returns the string containing the text of the specified header, or null if
  # either the response has not yet been received or the header doesn't exist in
  # the response.
  getResponseHeader: (header)->
    if @_responseHeaders
      return @_responseHeaders[header.toLowerCase()]
    else
      return null

  # Initializes a request.
  #
  # Calling this method an already active request (one for which open()or
  # openRequest()has already been called) is the equivalent of calling abort().
  open: (method, url, async, user, password)->
    if async == false
      throw new HTML.DOMException(HTML.NOT_SUPPORTED_ERR, "Zombie does not support synchronous XHR requests")

    # Abort any pending request.
    @abort()

    # Check supported HTTP method
    method = method.toUpperCase()
    if /^(CONNECT|TRACE|TRACK)$/.test(method)
      throw new HTML.DOMException(HTML.SECURITY_ERR, "Unsupported HTTP method")
    unless /^(DELETE|GET|HEAD|OPTIONS|POST|PUT)$/.test(method)
      throw new HTML.DOMException(HTML.SYNTAX_ERR, "Unsupported HTTP method")

    headers = {}

    # Normalize the URL and check security
    url = URL.parse(URL.resolve(@_window.location.href, url))
    # Don't consider port if they are standard for http and https
    if (url.protocol == 'https:' && url.port == '443') ||
       (url.protocol == 'http:' && url.port == '80')
      delete url.port

    unless /^https?:$/i.test(url.protocol)
      throw new HTML.DOMException(HTML.NOT_SUPPORTED_ERR, "Only HTTP/S protocol supported")
    url.hostname ||= @_window.location.hostname
    url.host =
    if url.port
      url.host = "#{url.hostname}:#{url.port}"
    else
      url.host = url.hostname
    if url.host != @_window.location.host
      headers.origin = @_window.location.protocol + "//" + @_window.location.host
      @_cors = headers.origin
    url.hash = null
    if user
      url.auth = "#{user}:#{password}"

    # Reset all the response fields.
    @status       = null
    @statusText   = null
    @responseText = null
    @responseXML  = null

    request =
      method:   method
      url:      URL.format(url)
      headers:  headers
    @_pending = request
    @_stateChanged(XMLHttpRequest.OPENED)
    return

  # Sends the request. If the request is asynchronous (which is the default),
  # this method returns as soon as the request is sent. If the request is
  # synchronous, this method doesn't return until the response has arrived.
  send: (data)->
    # Request must be opened.
    unless @readyState == XMLHttpRequest.OPENED
      throw new HTML.DOMException(HTML.INVALID_STATE_ERR,  "Invalid state")

    request = @_pending
    request.headers["content-type"] ||= "text/plain"
    # Make the actual request
    request.body = data
    request.timeout = @timeout
    @_window._eventQueue.http request.method, request.url, request, (error, response)=>
      if @_pending == request
        @_pending = null

      if error
        @status = 0
        @responseText = ""
        @_stateChanged(XMLHttpRequest.DONE)
        error = new HTML.DOMException(HTML.NETWORK_ERR, error.message)
        event = new Events.Event('xhr')
        event.initEvent('error', true, true)
        event.error = error
        @dispatchEvent(event)
        return

      if @_cors
        allowedOrigin = response.headers['access-control-allow-origin']
        unless (allowedOrigin == '*' || allowedOrigin == @_cors)
          error = new HTML.DOMException(HTML.SECURITY_ERR, "Cannot make request to different domain")
          event = new Events.Event('xhr')
          event.initEvent('error', true, true)
          event.error = error
          @dispatchEvent(event)
          # Also make sure this error reaches the window (other error take
          # care of by eventQueue.http)
          raise(element: @_window.document, from: __filename, scope: "XHR", error: error)
          return

      # Since the request was not aborted, we set all the fields here and change
      # the state to HEADERS_RECEIVED.
      @status           = response.statusCode
      @statusText       = response.statusText
      @_responseHeaders = response.headers
      @_stateChanged(XMLHttpRequest.HEADERS_RECEIVED)

      # Give the onreadystatechange a chance to fire from the previous state
      # change, then set the response fields and change the state to DONE.
      @_window._eventQueue.enqueue =>
        @responseText = response.body?.toString() || ""
        @responseXML = null
        @_stateChanged(XMLHttpRequest.DONE)

    return

  # Sets the value of an HTTP request header.You must call setRequestHeader()
  # after open(), but before send().
  setRequestHeader: (header, value)->
    unless @readyState == XMLHttpRequest.OPENED
      throw new HTML.DOMException(HTML.INVALID_STATE_ERR,  "Invalid state")
    request = @_pending
    request.headers[header.toString().toLowerCase()] = value.toString()
    return

  # Fire onreadystatechange event
  _stateChanged: (newState)->
    @readyState = newState
    if newState == XMLHttpRequest.DONE and @status isnt 0
      event = new Events.Event('xhr')
      event.initEvent('load', false, true)
      @dispatchEvent(event)
    if @onreadystatechange
      # Since we want to wait on these events, put them in the event loop.
      @_window._eventQueue.enqueue =>
        try
          @onreadystatechange.call(this)
        catch error
          raise(element: @_window.document, from: __filename, scope: "XHR", error: error)

  # Raise error coming from jsdom
  raise: (level, message, errObject)->
    raise(element: @_window.document, from: __filename, scope: "XHR", error: errObject.error)

# Lifecycle states
XMLHttpRequest.UNSENT = 0
XMLHttpRequest.OPENED = 1
XMLHttpRequest.HEADERS_RECEIVED = 2
XMLHttpRequest.LOADING = 3
XMLHttpRequest.DONE = 4


module.exports = XMLHttpRequest
