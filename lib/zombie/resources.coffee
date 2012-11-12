# Access to HTTP/file resources.
#
# Each browser has a Resources object it uses to make requests (load pages,
# XHR, etc) and log all resource history.  You can also use this through
# `browser.resources`, e.g. to download a resource using current cookies.
#
# This object is also an array that lists all resources requested, so you can
# inspect it to help with troubleshooting.  Each entry contains:
#
# request   - The request (see below)
# response  - The response (see below)
# target    - Target document/element (used when loading page, scripts)
#
# Requests have the following properties:
# method      - The request method (GET, POST, etc)
# url         - The request URL
# headers     - All headers used in making the request
# body        - Request body (POST and PUT only)
#
# Responses have the following properties:
# url         - The actual URL retrieved (redirects change this)
# statusCode  - Status code (200, 404, etc)
# statusText  - Status text (OK, Not Found, etc)
# headers     - Headers provided in response
# redirects   - Number of redirects followed
# body        - The response body (Buffer or String)


File        = require("fs")
HTML        = require("jsdom").dom.level3.html
Path        = require("path")
QS          = require("querystring")
Request     = require("request")
URL         = require("url")


class Resources extends Array
  constructor: (browser)->
    @browser = browser
    @before = []
    @after  = []
    this.addHandler(this.normalizeURL)
    this.addHandler(this.mergeHeaders)
    this.addHandler(this.createBody)
    this.addHandler(this.decodeBody)


  # Make an HTTP request (also supports file: protocol).
  #
  # method    - Request method (GET, POST, etc)
  # url       - Request URL
  # options   - See below
  # callback  - Called with error, or null and response
  #
  # Options:
  #   headers   - Name/value pairs of headers to send in request
  #   params    - Parameters to pass in query string or document body
  #   resource  - Used internally to handle redirects
  #   target    - Associates request with document/element
  #
  # Response contains:
  #   url         - Actual resource URL (changed by redirects)
  #   statusCode  - Status code
  #   statusText  - HTTP status text ("OK", "Not Found" etc)
  #   headers     - Response headers
  #   body        - Response body
  #   redirects   - Number of redirects followed
  request: (method, url, options, callback)->
    unless callback
      [options, callback] = [{}, options]

    request =
      method:  method.toUpperCase()
      url:     url
      headers: options.headers || {}
      params:  options.params

    resource =
      request:    request
      redirects:  0
      target:     options.target
    @push(resource)
    @browser.emit("request", resource)

    firstHandler = @before[0]
    firstHandler request, (error, response)=>
      if error
        resource.error = error
        callback(error)
      else
        resource.response = 
          url:        response.url || request.url
          statusCode: response.statusCode || 200
          statusText: STATUS[response.statusCode] || "OK"
          headers:    response.headers || {}
          redirects:  response.redirects || 0
          body:       response.body
        @browser.emit("response", resource)
        callback(null, resource.response)
    return


  # GET request.
  #
  # url       - Request URL
  # options   - See request() method
  # callback  - Called with error, or null and response
  get: (url, options, callback)->
    @request("get", url, options, callback)
    return

  # HTTP request.
  #
  # url       - Request URL
  # options   - See request() method
  # callback  - Called with error, or null and response
  post: (url, options, callback)->
    @request("post", url, options, callback)
    return


  addHandler: (handler)->
    handleResponse = (request, response, callback)=>
      nextHandler = @after[0]
      if nextHandler
        nextHandler(request, response, callback)
      else
        callback(null, response)


    if handler.length == 2
      chainWrapper = (request, callback)=>
        handler.call this, request, (error, response)=>
          if error
            callback(error)
            return
          # If we get a response, switch to the post-response chain
          if response
            handleResponse(response, callback)
            return
          # Pass to next handler in this chain or callback
          index = @before.indexOf(chainWrapper)
          nextHandler = @before[index + 1]
          if ~index && nextHandler
            nextHandler(request, callback)
          else
            @httpRequest request, (error, response)->
              if error
                callback(error)
              else
                handleResponse(request, response, callback)

      @before.push(chainWrapper)
    else
      chainWrapper = (request, response, callback)=>
        handler request, response, (error)=>
          if error
            callback(error)
            return
          # Pass to next handler in chain or callback
          index = @after.indexOf(chainWrapper)
          nextHandler = @after[index + 1]
          if ~index && nextHandler
            nextHandler(request, response, callback)
          else
            callback(null, response)

      @after.push(chainWrapper)


  # -- Process request
  
  # Normalize the request URL.  Turns relative URL into an absolute one and
  # fixes file URL with missing slashes.
  normalizeURL: (request, callback)->
    if /^file:/.test(request.url)
      # File URLs are special, need to handle missing slashes and not attempt
      # to parse (downcases path)
      request.url = request.url.replace(/^file:\/{1,3}/, "file:///")
    else
      # Resolve URL relative to document URL/base, or for new browser, using
      # Browser.site
      if @browser.document
        request.url = HTML.resourceLoader.resolve(@browser.document, request.url)
      else
        request.url = URL.resolve(@browser.site || "http://localhost", request.url)
    callback()
    return


  # Merges request headers with browser settings (headers, user agent, etc),
  # authentication credentials and cookies.
  mergeHeaders: (request, callback)->
    # Header names are down-cased and over-ride default
    headers =
      "user-agent":       @browser.userAgent
      "accept-encoding":  "identity" # No gzip/deflate support yet

    { host } = URL.parse(request.url)

    # Merge custom headers from browser first, followed by request.
    for name, value of @browser.headers
      headers[name.toLowerCase()] = value
    if request.headers
      for name, value of request.headers
        headers[name.toLowerCase()] = value
    # Depends on URL, don't allow over-ride.
    headers.host = host

    # Apply authentication credentials
    credentials = @browser.authenticate(host, false)
    if credentials
      credentials.apply(headers)

    request.headers = headers
    callback()
    return

 
  # Creates request body from parameters.
  createBody: (request, callback)->
    method = request.method
    if method == "POST" || method == "PUT"
      headers = request.headers
      # These methods support document body.  Create body or multipart.
      headers["content-type"] ||= "application/x-www-form-urlencoded"
      mimeType = headers["content-type"].split(";")[0]
      switch mimeType
        when "application/x-www-form-urlencoded"
          request.body = stringifyParams(request.params || {})
          headers["content-length"] = request.body.length
        when "multipart/form-data"
          params = request.params || []
          if params.length == 0
            # Empty parameters, can't use multipart
            headers["content-type"] = "text/plain"
            request.body = ""
          else
            boundary = "#{new Date().getTime()}.#{Math.random()}"
            headers["content-type"] += "; boundary=#{boundary}"
            multipart = []
            for field in params
              [name, content] = field
              disp = "form-data; name=\"#{name}\""
              if content.read
                binary = content.read()
                multipart.push
                  "Content-Disposition":  "#{disp}; filename=\"#{content}\""
                  "Content-Type":         content.mime || "application/octet-stream"
                  "Content-Length":       binary.length
                  body:                   binary
              else
                multipart.push
                  "Content-Disposition":        disp
                  "Content-Type":               "text/plain"
                  "Content-Transfer-Encoding":  "utf8"
                  "Content-Length":             content.length
                  body:                         content
            request.multipart = multipart
        when "text/plain"
          # XHR falls-back on this
        else
          process.nextTick ->
            resource.error = new Error("Unsupported content type #{mimeType}")
            callback(resource.error)
          return

    else if method == "GET" || method == "HEAD" || method == "DELETE"
      # These methods use query string parameters instead
      if request.params
        uri = URL.parse(request.url)
        uri.search = "?" + stringifyParams(request.params)
        request.url = URL.format(uri)

    callback()
    return


  # -- Make HTTP request


  # Make the actual request.
  httpRequest: (request, callback)->
    { protocol, hostname, pathname } = URL.parse(request.url)
    if protocol == "file:"
      # If the request is for a file:// descriptor, just open directly from the
      # file system rather than getting node's http (which handles file://
      # poorly) involved.
      if request.method == "GET"
        filename = Path.normalize(pathname)
        File.exists filename, (exists)=>
          if exists
            File.readFile filename, (error, buffer)=>
              # Fallback with error -> callback
              if error
                resource.error = error
                callback(error)
              else
                callback(null, body: buffer)
          else
            callback(null, statusCode: 404)
      else
        callback(resource.error)

    else

      # We're going to use cookies later when recieving response.
      cookies = @browser.cookies(hostname, pathname)
      cookies.addHeader(request.headers)

      httpRequest =
        method:         request.method
        url:            request.url
        headers:        request.headers
        body:           request.body
        multipart:      request.multipart
        proxy:          @browser.proxy
        jar:            false
        followRedirect: false

      Request httpRequest, (error, response)=>
        if error
          callback(error)
          return

        # Set cookies from response
        setCookie = response.headers["set-cookie"]
        if typeof(setCookie) == "string"
          cookies.update(setCookie)
        else if setCookie
          for cookie in setCookie
            cookies.update(cookie)

        # Number of redirects so far.
        redirects = request.redirects || 0

        # Determine whether to automatically redirect and which method to use
        # based on the status code
        switch response.statusCode
          when 301, 307
            # Do not follow POST redirects automatically, only GET/HEAD
            if method == "GET" || method == "HEAD"
              redirectURL = URL.resolve(request.url, response.headers.location)
          when 302, 303
            # Follow redirect using GET (e.g. after form submission)
            redirectURL = URL.resolve(request.url, response.headers.location)

        if redirectURL
          # Handle redirection, make sure we're not caught in an infinite loop
          ++redirects
          if redirects > @browser.maxRedirects
            callback(new Error("More than #{browser.maxRedirects} redirects, giving up"))
            return

          redirectHeaders = {}
          for name, value of request.headers
            redirectHeaders[name] = value
          # This request is referer for next
          redirectHeaders.referer = request.url
          # These headers exist in POST request, do not pass to redirect (GET)
          delete redirectHeaders["content-type"]
          delete redirectHeaders["content-length"]
          delete redirectHeaders["content-transfer-encoding"]

          redirectRequest =
            method:     "GET"
            url:        redirectURL
            headers:    redirectHeaders
            redirects:  redirects
          @httpRequest(redirectRequest, callback)

        else

          response =
            url:          request.url
            statusCode:   response.statusCode
            headers:      response.headers
            body:         response.body
            redirects:    redirects
          callback(null, response)
    return


  # -- Process response


  # Decode the response body.
  decodeBody: (request, response, callback)->
    # Use content type to determine how to decode response
    if response.body && response.headers
      contentType = response.headers["content-type"]
    if contentType
      [mimeType, typeOptions...] = contentType.split(/;\s+/)
      unless mimeType == "application/octet-stream"
        for typeOption in typeOptions
          if /^charset=/.test(typeOption)
            charset = typeOption.split("=")[1]
            break
        response.body = response.body.toString(charset || "utf8")
    callback()
    return




stringifyParams = (object)->
  unless object.map
    return object.toString()
  object.map((k) ->
    if Array.isArray(k[1])
      k[1].map((v) ->
        QS.escape(stringifyPrimitive(k[0])) + "=" + QS.escape(stringifyPrimitive(v))
      ).join("&")
    else
      QS.escape(stringifyPrimitive(k[0])) + "=" + QS.escape(stringifyPrimitive(k[1]))
  ).join("&")

# We use this to convert data array/hash into application/x-www-form-urlencoded
stringifyPrimitive = (value)->
  if typeof(value) == "string" || value instanceof String
    return value
  else if value == null || value == undefined
    return ""
  else
    return value.toString()


# HTTP status code to status text
STATUS =
  100: "Continue"
  101: "Switching Protocols"
  200: "OK"
  201: "Created"
  202: "Accepted"
  203: "Non-Authoritative"
  204: "No Content"
  205: "Reset Content"
  206: "Partial Content"
  300: "Multiple Choices"
  301: "Moved Permanently"
  302: "Found"
  303: "See Other"
  304: "Not Modified"
  305: "Use Proxy"
  307: "Temporary Redirect"
  400: "Bad Request"
  401: "Unauthorized"
  402: "Payment Required"
  403: "Forbidden"
  404: "Not Found"
  405: "Method Not Allowed"
  406: "Not Acceptable"
  407: "Proxy Authentication Required"
  408: "Request Timeout"
  409: "Conflict"
  410: "Gone"
  411: "Length Required"
  412: "Precondition Failed"
  413: "Request Entity Too Large"
  414: "Request-URI Too Long"
  415: "Unsupported Media Type"
  416: "Requested Range Not Satisfiable"
  417: "Expectation Failed"
  500: "Internal Server Error"
  501: "Not Implemented"
  502: "Bad Gateway"
  503: "Service Unavailable"
  504: "Gateway Timeout"
  505: "HTTP Version Not Supported"


module.exports = Resources
