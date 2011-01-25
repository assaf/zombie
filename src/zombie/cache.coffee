# Simple HTTP cache.
#
# Primary use is to emulate browser-side caching and act as a browser
# would (read from cache, validate, etc).
#
# In addition, the cache takes on some other common responsibilities:
# - Transform request data into the appropriate content type or use
#   query string parameters
# - Add cookies to requests, read cookies from responses
# - Follow redirects
# - Other HTTP request abstractions (add User-Agent header, fix URL
#   path, default ports, etc)

http = require("http")
QS = require("querystring")
URL = require("url")
vm = process.binding("evals")


class Cache
  constructor: (browser)->
    # ### cache.get(url, headers, callback)
    #
    # Makes a GET request using the cache.  See `request` for more
    # details about callback and response object.
    this.get = (url, callback)-> this.request "GET", url, null, null, callback

    # ### cache.request(method, url, data, headers, callback)
    #
    # Make a request using the cache.  Request method is one of "GET",
    # "POST", "PUT", "DELETE" or "HEAD".  Request URL must be absolute,
    # either a string or URL object.
    #
    # Additional parameters (`data`) are either encoded into the request
    # body or passed as query string parameters, depending on the method
    # and the `Content-Type` header.
    #
    # Supported content types are:
    # - `application/x-www-form-urlencoded` -- HTML forms use this by
    #   default
    # - `multipart/form-data` -- HTML forms use this when uploading files;
    #    any data field that has `contents`, `mime` and `encoding`
    #    properties is treated as file, and
    # - `application/json` -- Convert object to JSON
    # Anything else treats `data` as the string contents of the request.
    #
    # The callback is called with either an error, or with `null` and
    # response.  The response object has the following properties:
    # - body -- Response body
    # - cached -- True if response fulfilled by cache
    # - headers -- Response headers
    # - redirects -- Number of redirects followed
    # - script -- V8 compiled script
    # - statusCode -- HTTP status code
    # - statusText -- HTTP status text
    # - url -- Actual URL of this response (after following redirects)
    this.request = (method, url, data, headers, redirects, callback)->
      # Everyone else calls this without the redirects arguments
      [redirects, callback] = [0, redirects] unless callback

      url = URL.parse(url)
      method = (method || "GET").toUpperCase()
      redirects ||= 0 # start at zero
      # Clone headers before we go and modify them.
      headers = if headers then JSON.parse(JSON.stringify(headers)) else {}
      headers["User-Agent"] = browser.userAgent
      if method == "GET" || method == "HEAD"
        # Request paramters go in query string
        url.search = "?" + stringify(data) if data
        body = ""
      else
        # Construct body from request parameters.
        switch headers["content-type"]
          when "application/x-www-form-urlencoded"
            body = stringify(data)
          when "multipart/form-data"
            boundary = "#{new Date().getTime()}#{Math.random()}"
            lines = ["--#{boundary}"]
            data.map((item) ->
              name   = item[0]
              values = item[1]
              values = [values] unless typeof values == "array"

              for value in values
                disp = "Content-Disposition: form-data; name=\"#{name}\""

                if value.contents
                  disp += "; filename=\"#{value}\""
                  content = value.contents()
                  mime = value.mime()
                  encoding = value.encoding()
                else
                  content = value
                  mime = "text/plain"

                lines.push disp
                lines.push "Content-Type: #{mime}"
                lines.push "Content-Length: #{content.length}"
                lines.push "Content-Transfer-Encoding: base64" if encoding
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
            body = data.toString()
        headers["content-length"] = body.length

      # Pre 0.3 we need to specify the host name.
      headers["Host"] = url.host
      url.pathname = "/#{url.pathname || ""}" unless url.pathname && url.pathname[0] == "/"
      # We're going to use cookies later when recieving response.
      cookies = browser.cookies(url.hostname, url.pathname)
      cookies.addHeader headers
      # Pathname for HTTP request needs to start with / and include query
      # string.
      path = "#{url.pathname}#{url.search || ""}"
      secure = url.protocol == "https:"
      port = url.port || (if secure then 443 else 80)
      client = http.createClient(port, url.hostname, secure)
      request = client.request(method, path, headers)
      # Connection error wired directly to callback.
      client.on "error", callback
      request.on "response", (response)=>
        response.setEncoding "utf8"
        body = ""
        response.on "data", (chunk)-> body += chunk
        response.on "end", =>
          cookies.update response.headers["set-cookie"]

          # Turn body from string into a String, so we can add property getters.
          outcome = new Object()
          outcome.__defineGetter__ "body", -> body
          outcome.__defineGetter__ "cached", -> false
          outcome.__defineGetter__ "headers", -> response.headers
          outcome.__defineGetter__ "script", -> body._script ||= vm.Script(body, path)
          outcome.__defineGetter__ "statusCode", -> response.statusCode
          outcome.__defineGetter__ "statusText", -> STATUS[response.statusCode]
          outcome.__defineGetter__ "redirects", -> redirects
          outcome.__defineGetter__ "url", -> URL.format(url)
  
          error = null
          switch response.statusCode
            when 200, 201, 202, 204
              callback null, outcome
            when 301, 302, 303, 307
              if response.headers["location"]
                redirect = URL.resolve(URL.format(url), response.headers["location"])
                # Fail after fifth attempt to redirect, better than looping forever
                if (redirects += 1) > 5
                  error = new Error("Too many redirects, from #{URL.format(url)} to #{redirect}")
                else
                  process.nextTick =>
                    this.request "GET", redirect, null, null, redirects, callback
              else
                error = new Error("Redirect with no Location header, cannot follow")
            else
              error = new Error("Could not load resource at #{URL.format(url)}, got #{response.statusCode}")
          # Fallback with error -> callback
          if error
            error.response = outcome
            callback error
      request.end body, "utf8"

    # We use this to convert data array/hash into application/x-www-form-urlencoded
    stringifyPrimitive = (v) =>
      switch Object.prototype.toString.call(v)
        when '[object Boolean]' then v ? 'true' : 'false'
        when '[object Number]'  then isFinite(v) ? v : ''
        when '[object String]'  then v
        else ''

    stringify = (obj) =>
      sep = '&'
      eq = '='

      obj.map((k) ->
        if Array.isArray(k[1])
          k[1].map((v) ->
            QS.escape(stringifyPrimitive(k[0])) + eq + QS.escape(stringifyPrimitive(v))
          ).join(sep);
        else
          QS.escape(stringifyPrimitive(k[0])) + eq + QS.escape(stringifyPrimitive(k[1]))
      ).join(sep)


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


exports.cache = (browser)-> new Cache(browser)
