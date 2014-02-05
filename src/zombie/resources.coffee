# Retrieve resources (HTML pages, scripts, XHR, etc).
#
# If count is unspecified, defaults to at least one.
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


encoding  = require("encoding")
File      = require("fs")
HTML      = require("jsdom").dom.level3.html
Path      = require("path")
QS        = require("querystring")
Request   = require("request")
URL       = require("url")
HTTP      = require('http')
Zlib      = require("zlib")
assert    = require("assert")


# Each browser has a resources object that provides the means for retrieving
# resources and a list of all retrieved resources.
#
# The object is an array, and its elements are the resources.
class Resources extends Array
  constructor: (browser)->
    @browser = browser
    @pipeline = Resources.pipeline.slice()
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
  #   timeout   - Request timeout in milliseconds (0 or null for no timeout)
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
      method:     method.toUpperCase()
      url:        url
      headers:    options.headers || {}
      params:     options.params
      body:       options.body
      time:       Date.now()
      timeout:    options.timeout || 0
      strictSSL:  @browser.strictSSL

    resource =
      request:    request
      target:     options.target
    @push(resource)
    @browser.emit("request", request)

    @runPipeline request, (error, response)=>
      if error
        resource.error = error
        callback(error)
      else
        response.url        ||= request.url
        response.statusCode ||= 200
        response.statusText = HTTP.STATUS_CODES[response.statusCode] || "Unknown"
        response.headers    ||= {}
        response.redirects  ||= 0
        response.time       = Date.now()
        resource.response = response

        @browser.emit("response", request, response)
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
  # delay - Delay in milliseconds (defaults to 10)
  delay: (url, delay = 10)->
    delayTheResponse = (request, next)->
      setTimeout(next, delay)
    @urlMatchers.push([url, delayTheResponse])
    return

  # You can use this to return a particular result for a given URL.
  #
  # url     - The URL to mock
  # result  - The result to return (statusCode, headers, body)
  mock: (url, result = {})->
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


  # Add a request/response handler.  This handler will only be used by this
  # browser.
  addHandler: (handler)->
    assert handler.call, "Handler must be a function"
    assert handler.length == 2 || handler.length == 3, "Handler function takes 2 (request handler) or 3 (reponse handler) arguments"
    @pipeline.push(handler)

  # Processes the request using the pipeline.
  runPipeline: (request, callback)->
    requestHandlers = @pipeline.filter((fn)-> fn.length == 2)
    requestHandlers.push(Resources.makeHTTPRequest)
    responseHandlers = @pipeline.filter((fn)-> fn.length == 3)
    response = null

    # Called to execute the next request handler.
    nextRequestHandler = (error, responseFromHandler)=>
      if error
        callback(error)
      else if responseFromHandler
        # Received response, switch to processing request
        response = responseFromHandler
        # If we get redirected and the final handler doesn't provide a URL (e.g.
        # mock response), then without this we end up with the original URL.
        response.url ||= request.url
        nextResponseHandler()
      else
        # Use the next request handler.
        handler = requestHandlers.shift()
        try
          handler.call(@browser, request, nextRequestHandler)
        catch error
          callback(error)

    # Called to execute the next response handler.
    nextResponseHandler = (error)=>
      if error
        callback(error)
      else
        handler = responseHandlers.shift()
        if handler
          # Use the next response handler
          try
            handler.call(@browser, request, response, nextResponseHandler)
          catch error
            callback(error)
        else
          # No more handlers, callback with response.
          callback(null, response)

    # Start with first request handler
    nextRequestHandler()
    return


# -- Handlers

# Add a request/response handler.  This handler will be used in all browsers.
Resources.addHandler = (handler)->
  assert handler.call, "Handler must be a function"
  assert handler.length == 2 || handler.length == 3, "Handler function takes 2 (request handler) or 3 (response handler) arguments"
  @pipeline.push(handler)


# This handler normalizes the request URL.
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
    if @document
      request.url = HTML.resourceLoader.resolve(@document, request.url)
    else
      request.url = URL.resolve(@site || "http://localhost", request.url)

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


# This handler mergers request headers.
#
# It combines headers provided in the request with custom headers defined by
# the browser (user agent, authentication, etc).
#
# It also normalizes all headers by down-casing the header names.
Resources.mergeHeaders = (request, next)->
  # Header names are down-cased and over-ride default
  headers =
    "user-agent":       @userAgent

  # Merge custom headers from browser first, followed by request.
  for name, value of @headers
    headers[name.toLowerCase()] = value
  if request.headers
    for name, value of request.headers
      headers[name.toLowerCase()] = value

  { host } = URL.parse(request.url)

  # Depends on URL, don't allow over-ride.
  headers.host = host

  # Apply authentication credentials
  if credentials = @authenticate(host, false)
    credentials.apply(headers)

  request.headers = headers
  next()
  return


# Depending on the content type, this handler will create a request body from
# request.params, set request.multipart for uploads.
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
                    "Content-Type":               "text/plain; charset=utf8"
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
  for [url, handler] in @resources.urlMatchers
    if url == request.url
      handler(request, next)
      return
  next()


# Handle deflate and gzip transfer encoding.
Resources.decompressBody = (request, response, next)->
  if response.body && response.headers
    transferEncoding = response.headers["transfer-encoding"]
    contentEncoding = response.headers["content-encoding"]
  switch transferEncoding || contentEncoding
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


# This handler decodes the response body based on the response content type.
Resources.decodeBody = (request, response, next)->
  # Use content type to determine how to decode response
  if response.body && response.headers
    contentType = response.headers["content-type"]
  if contentType
    [mimeType, typeOptions...] = contentType.split(/;\s*/)
    [type,subtype] = contentType.split(/\//,2);
    unless mimeType == "application/octet-stream" || type == "image"
      for typeOption in typeOptions
        if /^charset=/.test(typeOption)
          charset = typeOption.split("=")[1]
          break
      response.body = encoding.convert(response.body.toString(), null, charset || "utf-8").toString()
  next()
  return


# All browsers start out with this list of handler.
Resources.pipeline = [
  Resources.normalizeURL
  Resources.mergeHeaders
  Resources.createBody
  Resources.specialURLHandlers
  Resources.decompressBody
  Resources.decodeBody
]


# -- Make HTTP request


# Used to perform HTTP request (also supports file: resources).  This is always
# the last request handler.
Resources.makeHTTPRequest = (request, callback)->
  { protocol, hostname, pathname } = URL.parse(request.url)
  if protocol == "file:"
    # If the request is for a file:// descriptor, just open directly from the
    # file system rather than getting node's http (which handles file://
    # poorly) involved.
    if request.method == "GET"
      filename = Path.normalize(decodeURI(pathname))
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
    cookies = @cookies
    request.headers.cookie = cookies.serialize(hostname, pathname)

    httpRequest =
      method:         request.method
      url:            request.url
      headers:        request.headers
      body:           request.body
      multipart:      request.multipart
      proxy:          @proxy
      jar:            false
      followRedirect: false
      encoding:       null
      strictSSL:      request.strictSSL
      timeout:        request.timeout || 0

    Request httpRequest, (error, response)=>
      if error
        callback(error)
        return

      # Set cookies from response
      setCookie = response.headers["set-cookie"]
      if setCookie
        cookies.update(setCookie, hostname, pathname)

      # Number of redirects so far.
      redirects = request.redirects || 0

      # Determine whether to automatically redirect and which method to use
      # based on the status code
      switch response.statusCode
        when 301, 307
          # Do not follow POST redirects automatically, only GET/HEAD
          if request.method == "GET" || request.method == "HEAD"
            response.url = URL.resolve(request.url, response.headers.location)
        when 302, 303
          # Follow redirect using GET (e.g. after form submission)
          response.url = URL.resolve(request.url, response.headers.location)

      if response.url
        # Handle redirection, make sure we're not caught in an infinite loop
        ++redirects
        if redirects > @maxRedirects
          callback(new Error("More than #{@maxRedirects} redirects, giving up"))
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
        # Redirect must follow the entire chain of handlers.
        redirectRequest =
          method:     "GET"
          url:        response.url
          headers:    redirectHeaders
          redirects:  redirects
          time:       request.time
          timeout:    request.timeout
        @emit("redirect", request, response)
        @resources.runPipeline(redirectRequest, callback)

      else

        response =
          url:          request.url
          statusCode:   response.statusCode
          headers:      response.headers
          body:         response.body
          redirects:    redirects
        callback(null, response)
  return

module.exports = Resources
