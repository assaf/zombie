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
# redirects - Number of redirects followed
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

    # Normalize method
    method = method.toUpperCase()

    if /^file:/.test(url)
      # File URLs are special, need to handle missing slashes and not attempt
      # to parse (downcases path)
      url = url.replace(/^file:\/{1,3}/, "file:///")
    else
      # Resolve URL relative to document URL/base, or for new browser, using
      # Browser.site
      if @browser.document
        url = HTML.resourceLoader.resolve(@browser.document, url)
      else
        url = URL.resolve(@browser.site || "http://localhost", url)
    # These are used elsewhere
    { protocol, host, hostname, pathname } = URL.parse(url)
    # Make sure pathname starts with /
    unless pathname && pathname[0] == "/"
      pathname = "/#{uri.pathname || ""}"
      uri = URL.parse(url)
      uri.pathname = pathname
      url = URL.stringify(uri)


    # Header names are down-cased and over-ride default
    headers =
      "user-agent":       @browser.userAgent
      "accept-encoding":  "identity" # No gzip/deflate support yet

    # Merge custom headers from browser first, followed by request.
    for name, value of @browser.headers
      headers[name.toLowerCase()] = value
    if options.headers
      for name, value of options.headers
        headers[name.toLowerCase()] = value
    # Depends on URL, don't allow over-ride.
    headers.host = host

    # Apply authentication credentials
    credentials = @browser.authenticate(host, false)
    if credentials
      credentials.apply(headers)

    # We're going to use cookies later when recieving response.
    cookies = @browser.cookies(hostname, pathname)
    cookies.addHeader(headers)
    # We only use the JAR for response cookies
    cookieJar = Request.jar()


    if method == "POST" || method == "PUT"
      # These methods support document body.  Create body or multipart.
      headers["content-type"] ||= "application/x-www-form-urlencoded"
      mimeType = headers["content-type"].split(";")[0]
      switch mimeType
        when "application/x-www-form-urlencoded"
          body = stringifyParams(options.params || {})
          headers["content-length"] = body.length
        when "multipart/form-data"
          if options.params.length == 0
            # Empty parameters, can't use multipart
            headers["content-type"] = "text/plain"
            body = ""
          else
            boundary = "#{new Date().getTime()}.#{Math.random()}"
            headers["content-type"] += "; boundary=#{boundary}"
            multipart = []
            for field in options.params
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
        when "text/plain"
          # XHR falls-back on this
        else
          process.nextTick ->
            resource.error = new Error("Unsupported content type #{mimeType}")
            callback(resource.error)
          return

    else if method == "GET" || method == "HEAD" || method == "DELETE"
      # These methods use query string parameters instead
      if options.params
        uri = URL.parse(url)
        uri.search = "?" + stringifyParams(options.params)
        url = URL.stringify(uri)


    # Resource created on first request, reused on redirect
    if options.resource
      resource = options.resource
    else
      resource =
        request:
          method:   method
          url:      url
          headers:  headers
          body:     body
        redirects:  0
        target:     options.target
      @push(resource)
      @browser.emit("request", resource)


    if protocol == "file:"
      # If the request is for a file:// descriptor, just open directly from the
      # file system rather than getting node's http (which handles file://
      # poorly) involved.
      if method == "GET"
        filename = Path.normalize(pathname)
        File.exists filename, (exists)=>
          if exists
            File.readFile filename, (error, buffer)=>
              # Fallback with error -> callback
              if error
                resource.error = error
                callback(error)
              else
                resource.response =
                  url:          url
                  statusCode:   200
                  statusText:   "OK"
                  headers:      {}
                  body:         buffer
                  redirects:    0
                @browser.emit("response", resource)
                callback(null, resource.response)
          else
            resource.response =
              url:          url
              statuscode:   404
              statustext:   "Not Found"
              headers:      {}
              body:         null
              redirects:    0
            @browser.emit("response", resource)
            callback(null, resource.response)
      else
        process.nextTick ->
          resource.error = new Error("Cannot use #{method} with a file URL")
          callback(resource.error)

    else

      request =
        method:         method
        url:            url
        headers:        headers
        body:           body
        multipart:      multipart
        proxy:          @browser.proxy
        jar:            cookieJar
        followRedirect: false

      Request request, (error, response)=>
        if error
          resource.error = error
          callback(error)
          return

        # Set cookies from response
        for cookie in cookieJar.cookies
          cookies.update(cookie.str)

        # Determine whether to automatically redirect and which method to use
        # based on the status code
        switch response.statusCode
          when 301, 307
            # Do not follow POST redirects automatically, only GET/HEAD
            if method == "GET" || method == "HEAD"
              redirectURL = URL.resolve(url, response.headers.location)
          when 302, 303
            # Follow redirect using GET (e.g. after form submission)
            redirectURL = URL.resolve(url, response.headers.location)

        if redirectURL
          # Handle redirection, make sure we're not caught in an infinite loop
          ++resource.redirects
          if resource.redirects > @browser.maxRedirects
            resource.error = new Error("More than #{browser.maxRedirects} redirects, giving up")
            callback(resource.error)
            return

          redirectHeaders = {}
          for name, value of headers
            redirectHeaders[name] = value
          # This request is referer for next
          redirectHeaders.referer = url
          # These headers exist in POST request, do not pass to redirect (GET)
          delete redirectHeaders["content-type"]
          delete redirectHeaders["content-length"]
          delete redirectHeaders["content-transfer-encoding"]
          @get(redirectURL, headers: redirectHeaders, resource: resource, target: options.target, callback)
        else
          # Use content type to determine how to decode response
          if response.body && contentType = response.headers["content-type"]
            [mimeType, typeOptions...] = contentType.split(/;\s+/)
            unless mimeType == "application/octet-stream"
              for typeOption in typeOptions
                if /^charset=/.test(typeOption)
                  charset = typeOption.split("=")[1]
                  break
              body = response.body.toString(charset || "utf8")

          resource.response =
            url:          url
            statusCode:   response.statusCode
            statusText:   STATUS[response.statusCode] || "Unknown"
            headers:      response.headers
            body:         body || response.body
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
