# Resources loaded by a window.
#
# Each Window has a `resources` object that records resources (page,
# JavaScript, XHR requests, etc) loaded by the document.  This provides
# a request/response trail you can inspect when troubleshooting the
# page.  The resources list is cleared each time the window reloads.
#
# If you're familiar with the WebKit Inspector Resources pane, this does
# the same thing.

inspect = require("util").inspect
HTTP = require("http")
HTTPS = require("https")
FS = require("fs")
Path = require("path")
QS = require("querystring")
URL = require("url")


partial = (text, length = 250)->
  return text if text.length <= length
  return text.substring(0, length - 3) + "..."
indent = (text)->
  text.toString().split("\n").map((l)-> "  #{l}").join("\n")


# Represents a resource loaded by the window.  You can use this to peer
# into requests made by the browser, from resources linked to the
# document, XHR requests, etc.
#
# Each resource consists of:
# - elapsed -- Time took to complete the response in milliseconds
# - request -- Represents the request, see HTTPRequest
# - response -- Represents the response, see HTTPResponse
# - size -- Response size in bytes
# - url -- Resource URL
class Resource
  constructor: (request)->
    request.resource = this
    @redirects = 0
    start = new Date().getTime()
    elapsed = 0
    _response = null
    @__defineGetter__ "request", -> request
    @__defineGetter__ "response", -> _response
    @__defineGetter__ "size", -> response?.body.length || 0
    @__defineGetter__ "time", -> elapsed
    @__defineGetter__ "url", -> response?.url || request.url
    @__defineSetter__ "response", (response)->
      elapsed = new Date().getTime() - start
      response.resource = this
      _response = response
    this.toString = ->
      "URL:      #{@url}\nTime:     #{@time}ms\nSize:     #{@size / 1024}kb\nRequest:\n#{indent @request}\nResponse:\n#{indent @response}\n"


# Represents a request.  You can get all past requests from the
# resource list.
#
# Each request has:
# - body -- Document body (empty for GET and HEAD)
# - headers -- All headers passed to the server
# - method -- HTTP method name
# - resource -- Reference to the Resource object
# - url -- Full request URL
class HTTPRequest
  constructor: (method, url, headers, body)->
    @__defineGetter__ "method", -> method
    @__defineGetter__ "url", -> URL.format(url)
    @__defineGetter__ "headers", -> headers
    @__defineGetter__ "body", -> body
    this.toString = -> "#{inspect @headers}\n#{partial @body}"


# Represents a response.  You can get all past requests from the
# resource list.  This object is also passed to the callback with all
# the information you will need to process the response.
#
# Each response has:
# - body -- Document body
# - headers -- All headers returned from the server
# - redirected -- True if redirected before processing response
# - resource -- Reference to the Resource object
# - statusCode -- Status code returned from the server
# - statusText -- Text string associated with status code
# - url -- URL of the resource (after redirect)
class HTTPResponse
  constructor: (url, statusCode, headers, body)->
    @__defineGetter__ "body", -> body
    @__defineGetter__ "headers", -> headers
    @__defineGetter__ "statusCode", -> statusCode
    @__defineGetter__ "statusText", -> STATUS[statusCode]
    @__defineGetter__ "redirected", -> !!@resource.redirects
    @__defineGetter__ "url", -> URL.format(url)
    this.toString = -> "#{@statusCode} #{@statusText}\n#{inspect @headers}\n#{partial @body}"


# The resources list is essentially an array, and new resources
# (Resource objects) are added as they are loaded.  The array also
# supports the `request` method and the shorthand `get`.
class Resources extends Array
  constructor: (window)->
    window.resources = this

    # Returns the first resource in this array (the page loaded by this
    # window).
    this.__defineGetter__ "first", -> this[0]
    # Returns the last resource in this array.
    this.__defineGetter__ "last", -> this[this.length - 1]

    # Makes a GET request.  See `request` for more details about
    # callback and response object.
    this.get = (url, callback)-> this.request "GET", url, null, null, callback

    # Makes a request.  Requires HTTP method and resource URL.
    #
    # Optional data object is used to construct query string parameters
    # or request body (e.g submitting a form).
    #
    # Optional headers are passed to the server.  When making a POST/PUT
    # request, you probably want specify the `content-type` header.
    #
    # The callback is called with error and response (see `HTTPResponse`).
    this.request = (method, url, data, headers, callback)->
      window._eventloop.perform (done)->
        makeRequest method, url, data, headers, null, (error, response)->
          done()
          callback error, response

    # Dump all resources to the console by calling toString.
    this.dump = -> console.log this.toString()
    this.toString = ->
      this.map((resource)-> resource.toString()).join("\n")

    # Implementation of the request method, which also accepts the
    # resource.  Initially the resource is null, but when following a
    # redirect this function is called again with a resource and
    # modifies it instead of recording a new one.
    makeRequest = (method, url, data, headers, resource, callback)=>
      url = URL.parse(url)
      method = (method || "GET").toUpperCase()

      # If the request is for a file:// descriptor, just open directly from the
      # file system rather than getting node's http (which handles file://
      # poorly) involved.
      if url.protocol == "file:"
        window.browser.log -> "#{method} #{url.pathname}"
        if method == "GET"
          FS.readFile Path.normalize(url.pathname), (err, data) =>
            console.log err
            # Fallback with error -> callback
            if err
              window.browser.log -> "Error loading #{URL.format(url)}: #{err.message}"
              callback err
            # Turn body from string into a String, so we can add property getters.
            response = new HTTPResponse(url, 200, {}, String(data))
            callback null, response
        else
          callback new Error("Cannot #{method} a file: URL")
        return

      # Clone headers before we go and modify them.
      headers = if headers then JSON.parse(JSON.stringify(headers)) else {}
      headers["User-Agent"] = window.navigator.userAgent
      if method == "GET" || method == "HEAD"
        # Request paramters go in query string
        url.search = "?" + stringify(data) if data
        body = ""
      else
        # Construct body from request parameters.
        switch headers["content-type"]
          when "application/x-www-form-urlencoded"
            body = stringify(data || {})
          when "multipart/form-data"
            boundary = "#{new Date().getTime()}#{Math.random()}"
            lines = ["--#{boundary}"]
            (data || {}).map((item) ->
              name   = item[0]
              values = item[1]
              values = [values] unless typeof values == "array"

              for value in values
                disp = "Content-Disposition: form-data; name=\"#{name}\""
                encoding = null

                if value.read
                  content = value.read()
                  disp += "; filename=\"#{value}\""
                  mime = value.mime
                  encoding = "base64" unless value.mime == "text/plain"
                else
                  content = value
                  mime = "text/plain"

                switch encoding
                  when "base64" then content = content.toString("base64")
                  when "7bit" then content = content.toString("ascii")
                  when null
                  else
                    callback new Error("Unsupported transfer encoding #{encoding}")
                    return

                lines.push disp
                lines.push "Content-Type: #{mime}"
                lines.push "Content-Length: #{content.length}"
                lines.push "Content-Transfer-Encoding: #{encoding}" if encoding
                lines.push ""
                lines.push content
                lines.push "--#{boundary}"
            )
            if lines.length < 2
              body = ""
            else
              body = lines.join("\r\n") + "--\r\n"
            headers["content-type"] += "; boundary=#{boundary}"
          else
            # Fallback on sending text. (XHR falls-back on this)
            headers["content-type"] ||= "text/plain;charset=UTF-8"
            body = if data then data.toString() else ""
        headers["content-length"] = body.length

      # Pre 0.3 we need to specify the host name.
      headers["Host"] = url.host
      url.pathname = "/#{url.pathname || ""}" unless url.pathname && url.pathname[0] == "/"
      url.hash = null
      # We're going to use cookies later when recieving response.
      cookies = window.browser.cookies(url.hostname, url.pathname)
      cookies.addHeader headers
      # Pathname for HTTP request needs to start with / and include query
      # string.
      secure = url.protocol == "https:"
      url.port ||= if secure then 443 else 80

      # First request has not resource, so create it and add to
      # Resources.  After redirect, we have a resource we're using.
      unless resource
        resource = new Resource(new HTTPRequest(method, url, headers, body))
        this.push resource
      window.browser.log -> "#{method} #{URL.format(url)}"

      request =
        host: url.hostname
        port: url.port
        path: "#{url.pathname}#{url.search || ""}"
        method: method
        headers: headers
      response_handler = (response)=>
        response.setEncoding "utf8"
        body = ""
        response.on "data", (chunk)-> body += chunk
        response.on "end", =>
          cookies.update response.headers["set-cookie"]

          # Turn body from string into a String, so we can add property getters.
          resource.response = new HTTPResponse(url, response.statusCode, response.headers, body)

          error = null
          switch response.statusCode
            when 200, 201, 202, 204
              window.browser.log -> "#{method} #{URL.format(url)} => #{response.statusCode}"
              callback null, resource.response
            when 301, 302, 303, 307
              if response.headers["location"]
                redirect = URL.resolve(URL.format(url), response.headers["location"])
                # Fail after fifth attempt to redirect, better than looping forever
                if (resource.redirects += 1) > 5
                  error = new Error("Too many redirects, from #{URL.format(url)} to #{redirect}")
                else
                  process.nextTick =>
                    makeRequest "GET", redirect, null, null, resource, callback
              else
                error = new Error("Redirect with no Location header, cannot follow")
            else
              error = new Error("Could not load resource at #{URL.format(url)}, got #{response.statusCode}")
          # Fallback with error -> callback
          if error
            window.browser.log -> "Error loading #{URL.format(url)}: #{error.message}"
            error.response = resource.response
            resource.error = error
            callback error
      
      client = (if secure then HTTPS else HTTP).request(request, response_handler)
      # Connection error wired directly to callback.
      client.on "error", callback
      client.write body
      client.end()

    typeOf = (object)->
      return Object.prototype.toString.call(object)

    # We use this to convert data array/hash into application/x-www-form-urlencoded
    stringifyPrimitive = (v) =>
      switch typeOf(v)
        when '[object Boolean]' then v ? 'true' : 'false'
        when '[object Number]'  then isFinite(v) ? v : ''
        when '[object String]'  then v
        else ''

    stringify = (object) =>
      return object.toString() unless object.map
      object.map((k) ->
        if Array.isArray(k[1])
          k[1].map((v) ->
            QS.escape(stringifyPrimitive(k[0])) + "=" + QS.escape(stringifyPrimitive(v))
          ).join("&");
        else
          QS.escape(stringifyPrimitive(k[0])) + "=" + QS.escape(stringifyPrimitive(k[1]))
      ).join("&")



class Cache
  constructor: (browser)->
    #resources = new Resources(browser.window)
    # Makes a GET request using the cache.  See `request` for more
    # details about callback and response object.
    this.get = (url, callback)-> this.request "GET", url, null, null, callback
    this.request = (method, url, data, headers, callback)->
      resources.request method, url, data, headers, callback

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


# Add resources to window.
exports.extend = (window)-> new Resources(window)
