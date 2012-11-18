# Retrieve resources (HTML pages, scripts, XHR, etc).
#
# Each browser has a resources objects that allows you to:
# - Retrieve resources (see request, get and post).
# - Access the history of all resources loaded (pages, JS, etc).
# - Simulate server failure, delayed responses and mock responses.
# - Defines the means for retrieving resources (see below).
#
#
# This object is an Array that collects all resources retrieved by the browser.
# You can use this to inspect HTTP requests made by the browser.
#
# Each entry represents a single resource, an object with the properties:
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
#
#
# You can also use this object directly to retrieve resources, using the same
# HTTP processing available to the browser (cookies, credentials, etc).  For
# example:
#
#   browser.resources.get("/somepath", function(error, response) {
#     . . .
#   });
#
#
# To better simulate real servers and networks you can do the following:
# - Cause a particular request to always fail by calling `resources.fail(url,
#   message)`.  The error message is optional.
# - Cause a particular response to get delayed by calling `resources.delay(url,
#   ms)`.  Use this to simulate slow networks, or change the order in which
#   resources are loaded.
# - Cause a particular request to return whichever result by calling
#   `resources.mock(url, result)`.  You can use this to return any result
#   (`statusCode`, `headers` or `body`) you want.
#
# If you need to simulate a temporary glitch, you can remove any of these
# special handlers by calling `resource.restore(url)`.
#
#
# Resources are retrieved and processed using a chain of filters.  Filters that
# take two arguments are applied first.  The first argument is the request
# object, and the second argument is a callback.
#
# This filter chain is terminated when the callback is called with either
# error, or null and response object.  Call the callback with no arguments to
# pass control to the next filter.
#
# The last filter in this chain will always retrieve the resource (HTTP or file
# system), but you can add your own filters and provide your own mechanism for
# retrieving resources.
#
# Filters that take three arguments are applied next.  They recieve the
# request, response and a callback.  That chain terminates after the last
# filter, or if the callback is called with an error.  Again, each filter must
# call the callback to pass control to the next filter.
#
# For example, if you wanted to simulate a real network and delay all request
# by an random amount of time, you could do this:
#
#   browser.resources.addFilter(function(request, next) {
#     setTimeout(function() {
#       Resources.httpRequest(request, next);
#     }, Math.random() * 100);
#   });
#
# You can also use `resources.fail` for the same effect.
#
#
# If you write a generic filter and you want it to apply to all browsers, add
# it to Browser.Resources instead, for example:
#
#   Browser.Resources.addFilter(function(request, response, next) {
#     console.log("Response body: " + response.body);
#     next();
#   });
#
# These filters are added to every new browser.resources and immidiately bound
# to the browser object.


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
      for param in request.params
        uri.query[param[0]] = param[1]
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


# -- Helper functions

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
