# Retrieve resources (HTML pages, scripts, XHR, etc).
#
# Each browser has a resources objects that allows you to:
# - Inspect the history of retrieved resources, useful for troubleshooting
#   issues related to resource loading
# - Simulate a failed server
# - Change the order in which resources are retrieved, or otherwise introduce
#   delays to simulate a real world network
# - Mock responses from servers you don't have access to, or don't want to
#   access from test environment
# - Request resources directly, but have Zombie handle cookies,
#   authentication, etc
# - Implement new mechanism for retrieving resources, for example, add new
#   protocols or support new headers


File    = require("fs")
HTML    = require("jsdom").dom.level3.html
Path    = require("path")
QS      = require("querystring")
Request = require("request")
URL     = require("url")
Zlib    = require("zlib")


# Each browser has a resources object that provides the means for retrieving
# resources and a list of all retrieved resources.
#
# The object is an array, and its elements are the resources.
class Resources extends Array
  constructor: (browser)->
    @browser = browser
    @filters = []
    for i, filter of Resources.filters
      @filters[i] = filter.bind(this)
    @urlMatchers = []


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
  #   body      - Request document body
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
      body:    options.body
      time:    Date.now()

    resource =
      request:    request
      redirects:  0
      target:     options.target
    @push(resource)
    @browser.emit("request", resource)

    this.runFilters request, (error, response)=>
      if error
        resource.error = error
        callback(error)
      else
        response.url        ||= request.url
        response.statusCode ||= 200
        response.statusText = STATUS[response.statusCode] || "Unknown"
        response.headers    ||= {}
        response.redirects  ||= 0
        response.time       = Date.now()
        resource.response = response

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


  # You can use this to make a request to a given URL fail.
  #
  # url     - URL to fail
  # message - Optional error message
  fail: (url, message)->
    failTheRequest = (request, next)->
      next(new Error(message || "This request was intended to fail"))
    @urlMatchers.push([url, failTheRequest])
    return

  # You can use this to delay a response from a given URL.
  #
  # url   - URL to delay
  # delay - Delay in milliseconds
  delay: (url, delay)->
    delayTheResponse = (request, next)->
      setTimeout(next, delay)
    @urlMatchers.push([url, delayTheResponse])
    return

  # You can use this to return a particular result for a given URL.
  #
  # url     - The URL to mock
  # result  - The result to return (statusCode, headers, body)
  mock: (url, result)->
    mockTheResponse = (request, next)->
      next(null, result)
    @urlMatchers.push([url, mockTheResponse])
    return

  # You can use this to restore default behavior to after using fail, delay or
  # mock.
  restore: (url)->
    @urlMatchers = @urlMatchers.filter(([match, _])-> match != url)
    return


  # Human readable resource listing.  With no arguments, write it to stdout.
  dump: (output = process.stdout)->
    for resource in this
      { request, response, error, target } = resource
      # Write summary request/response header
      if response
        output.write "#{request.method} #{response.url} - #{response.statusCode} #{response.statusText} - #{response.time - request.time}ms\n"
      else
        output.write "#{resource.request.method} #{resource.request.url}\n"

      # Tell us which element/document is loading this.
      if target instanceof HTML.Document
        output.write "  Loaded as HTML document\n"
      else if target
        if target.id
          output.write "  Loading by element ##{target.id}\n"
        else
          output.write "  Loading as #{target.tagName} element\n"

      # If response, write out response headers and sample of document entity
      # If error, write out the error message
      # Otherwise, indicate this is a pending request
      if response
        if response.redirects
          output.write "  Followed #{response.redirects} redirects\n"
        for name, value of response.headers
          output.write "  #{name}: #{value}\n"
        output.write "\n"
        sample = response.body.slice(0, 250).toString("utf8")
          .split("\n").map((line)-> "  #{line}").join("\n")
        output.write sample
      else if error
        output.write "  Error: #{error.message}\n"
      else
        output.write "  Pending since #{new Date(request.time)}\n"
      # Keep them separated
      output.write "\n\n"


  # Add a before/after filter.  This filter will only be used by this browser.
  #
  #
  # A function with two arguments will be executed in order to prepare the
  # request, and will be called with request object and a callback.
  #
  # If the callback is called with an error, processing of the request stops.
  #
  # It the callback is called with no arguments, the next filter will be used.
  #
  # If the callback is called with null/undefined and request, that will
  # request will be used.
  #
  #
  # A function with three arguments will be executed in order to process the
  # resposne, and will be called with request object, response object and a
  # callback.
  #
  # If the callback is called with an error, processing of the response stops.
  #
  # If the callback is called with no no error, the next filter will be used.
  addFilter: (filter)->
    assert filter.call, "Filter must be a function"
    assert filter.length == 2 || filter.length == 3, "Filter function takes 2 (before filter) or 3 (after filter) arguments"
    @filters.push(filter)

  # Processes the request using a chain of filters.
  runFilters: (request, callback)->
    beforeFilters = @filters.filter((fn)-> fn.length == 2)
    beforeFilters.push(Resources.httpRequest.bind(this))
    afterFilters = @filters.filter((fn)-> fn.length == 3)
    response = null

    # Called to execute the next 'before' filter.
    beforeFilterCallback = (error, responseFromFilter)->
      if error
        callback(error)
      else if responseFromFilter
        # Received response, switch to processing request
        response = responseFromFilter
        afterFilterCallback()
      else
        # Use the next before filter.
        filter = beforeFilters.shift()
        try
          filter(request, beforeFilterCallback)
        catch error
          callback(error)

    # Called to execute the next 'after' filter.
    afterFilterCallback = (error)->
      if error
        callback(error)
      else
        filter = afterFilters.shift()
        if filter
          # Use the next after filter.
          try
            filter(request, response, afterFilterCallback)
          catch error
            callback(error)
        else
          # No more filters, callback with response.
          callback(null, response)

    # Start with first before filter
    beforeFilterCallback()
    return


# -- Filters

# Add a before/after filter.  This filter will be used in all browsers.
#
# Filters used before the request take two arguments.  Filters used with the
# response take three arguments.
#
# These filters are bound to the resources object.
Resources.addFilter = (filter)->
  assert filter.call, "Filter must be a function"
  assert filter.length == 2 || filter.length == 3, "Filter function takes 2 (before filter) or 3 (after filter) arguments"
  @filters.push(filter)


# This filter normalizes the request URL.
#
# It turns relative URLs into absolute URLs based on the current document URL
# or base element, or if no document open, based on browser.site property.
#
# Also handles file: URLs and creates query string from request.params for
# GET/HEAD/DELETE requests.
Resources.normalizeURL = (request, next)->
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

  if request.params
    method = request.method
    if method == "GET" || method == "HEAD" || method == "DELETE"
      # These methods use query string parameters instead
      uri = URL.parse(request.url, true)
      for name, value of request.params
        uri.query[name] = value
      request.url = URL.format(uri)

  next()
  return


# This filter mergers request headers.
#
# It combines headers provided in the request with custom headers defined by
# the browser (user agent, authentication, etc).
#
# It also normalizes all headers by down-casing the header names.
Resources.mergeHeaders = (request, next)->
  # Header names are down-cased and over-ride default
  headers =
    "user-agent":       @browser.userAgent
    "accept-encoding":  "identity" # No gzip/deflate support yet

  # Merge custom headers from browser first, followed by request.
  for name, value of @browser.headers
    headers[name.toLowerCase()] = value
  if request.headers
    for name, value of request.headers
      headers[name.toLowerCase()] = value

  { host } = URL.parse(request.url)

  # Depends on URL, don't allow over-ride.
  headers.host = host

  # Apply authentication credentials
  if credentials = @browser.authenticate(host, false)
    credentials.apply(headers)

  request.headers = headers
  next()
  return


# Depending on the content type, this filter will create a request body from
# request.params, set request.multipart for uploads, 
Resources.createBody = (request, next)->
  method = request.method
  if method == "POST" || method == "PUT"
    headers = request.headers
    # These methods support document body.  Create body or multipart.
    headers["content-type"] ||= "application/x-www-form-urlencoded"
    mimeType = headers["content-type"].split(";")[0]
    unless request.body
      switch mimeType
        when "application/x-www-form-urlencoded"
          request.body = QS.stringify(request.params || {})
          headers["content-length"] = request.body.length
        when "multipart/form-data"
          params = request.params || {}
          if Object.keys(params).length == 0
            # Empty parameters, can't use multipart
            headers["content-type"] = "text/plain"
            request.body = ""
          else
            boundary = "#{new Date().getTime()}.#{Math.random()}"
            headers["content-type"] += "; boundary=#{boundary}"
            multipart = []
            for name, values of params
              for value in values
                disp = "form-data; name=\"#{name}\""
                if value.read
                  binary = value.read()
                  multipart.push
                    "Content-Disposition":  "#{disp}; filename=\"#{value}\""
                    "Content-Type":         value.mime || "application/octet-stream"
                    "Content-Length":       binary.length
                    body:                   binary
                else
                  multipart.push
                    "Content-Disposition":        disp
                    "Content-Type":               "text/plain"
                    "Content-Transfer-Encoding":  "utf8"
                    "Content-Length":             value.length
                    body:                         value
            request.multipart = multipart
        when "text/plain"
          # XHR requests use this by default
        else
          next(new Error("Unsupported content type #{mimeType}"))
          return

  next()
  return


# Special URL handlers can be used to fail or delay a request, or mock a
# response.
Resources.specialURLHandlers = (request, next)->
  for [url, handler] in @urlMatchers
    if url == request.url
      handler(request, next)
      return
  next()


# Handle deflate and gzip transfer encoding.
Resources.decompressBody = (request, response, next)->
  if response.body && response.headers
    transferEncoding = response.headers["transfer-encoding"]
  switch transferEncoding
    when "deflate"
      Zlib.inflate response.body, (error, buffer)->
        unless error
          response.body = buffer
        next(error)
    when "gzip"
      Zlib.gunzip response.body, (error, buffer)->
        unless error
          response.body = buffer
        next(error)
    else
      next()
  return


# This filter decodes the response body based on the response content type.
Resources.decodeBody = (request, response, next)->
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
  next()
  return


# All browsers start out with this list of filters.
Resources.filters = [
  Resources.normalizeURL
  Resources.mergeHeaders
  Resources.createBody
  Resources.specialURLHandlers
  Resources.decompressBody
  Resources.decodeBody
]


# -- Make HTTP request


# Used to perform HTTP request (also supports file: resources).  This is always
# the last 'before' filter.
Resources.httpRequest = (request, callback)->
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
      encoding:       null

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
          if request.method == "GET" || request.method == "HEAD"
            redirectURL = URL.resolve(request.url, response.headers.location)
        when 302, 303
          # Follow redirect using GET (e.g. after form submission)
          redirectURL = URL.resolve(request.url, response.headers.location)

      if redirectURL
        # Handle redirection, make sure we're not caught in an infinite loop
        ++redirects
        if redirects > @browser.maxRedirects
          callback(new Error("More than #{@browser.maxRedirects} redirects, giving up"))
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
        Resources.httpRequest.call(this, redirectRequest, callback)

      else

        response =
          url:          request.url
          statusCode:   response.statusCode
          headers:      response.headers
          body:         response.body
          redirects:    redirects
        callback(null, response)
  return



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
