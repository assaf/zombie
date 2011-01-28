# See [RFC 2109](http://tools.ietf.org/html/rfc2109.html) and
# [document.cookie](http://developer.mozilla.org/en/document.cookie)
URL = require("url")
core = require("jsdom").dom.level3.core


# Serialize cookie object into RFC2109 representation.
serialize = (browser, domain, path, name, cookie)->
  str = "#{name}=#{cookie.value}; domain=#{domain}; path=#{path}"
  str = str + "; max-age=#{cookie.expires - browser.clock}" if cookie.expires
  str = str + "; secure" if cookie.secure
  str

# Unserialize a cookie
unserialize = (serialized)->
  fields = serialized.split(/;+/)
  first = fields[0].trim()
  [name, value] = first.split(/\=/, 2)

  cookie = name: name, value: value
  for field in fields
    [key, val] = field.trim().split(/\=/, 2)
    switch key.toLowerCase()
      when "domain"   then cookie.domain = dequote(val)
      when "path"     then cookie.path   = dequote(val).replace(/%[^\/]*$/, "")
      when "expires"  then cookie.expires = new Date(dequote(val))
      when "max-age"  then cookie['max-age'] = parseInt(dequote(val), 10)
      when "secure"   then cookie.secure = true
  return cookie

# Cookie header values are (supposed to be) quoted. This function strips
# double quotes aroud value, if it finds both quotes.
dequote = (value)-> value.replace(/^"(.*)"$/, "$1")

# Maintains cookies for a Browser instance. This is actually a domain/path
# specific scope around the global cookies collection.
class Cookies
  constructor: (browser, cookies, hostname, pathname)->
    pathname = "/" if !pathname || pathname == ""

    domainMatch = (domain, hostname)->
      return true if domain == hostname
      return domain.charAt(0) == "." && domain.substring(1) == hostname.replace(/^[^.]+\./, "")

    # Return all the cookies that match the given hostname/path, from most
    # specific to least specific. Returns array of arrays, each item is
    # [domain, path, name, cookie].
    selected = ->
      matching = []
      for domain, in_domain of cookies
        # Ignore cookies that don't match the exact hostname, or .domain.
        continue unless domainMatch(domain, hostname)
        # Ignore cookies that don't match the path.
        for path, in_path of in_domain
          continue unless pathname.indexOf(path) == 0
          for name, cookie of in_path
            # Delete expired cookies.
            if typeof cookie.expires == "number" && cookie.expires <= browser.clock
              delete in_path[name]
            else
              matching.push [domain, path, name, cookie]
      # Sort from most specific to least specified. Only worry about path
      # (longest is more specific)
      matching.sort (a,b) -> a[1].length - b[1].length

    #### cookies(host, path).get(name) => String
    #
    # Returns the value of a cookie.
    #
    # * name -- Cookie name
    # * Returns cookie value if known
    this.get = (name)->
      for match in selected()
        return match[3].value if match[2] == name

    #### cookies(host, path).set(name, value, options?)
    #
    # Sets a cookie (deletes if expires/max-age is in the past).
    #
    # * name -- Cookie name
    # * value -- Cookie value
    # * options -- Options max-age, expires, secure, domain, path
    this.set = (name, value, options = {})->
      return if options.domain && !domainMatch(options.domain, hostname)
      
      name = name.toLowerCase()
      state = { value: value.toString() }
      if options.expires
        state.expires = options.expires.getTime()
      else
        maxage = options["max-age"]
        state.expires = browser.clock + maxage if typeof maxage is "number"
      state.secure = true if options.secure
      
      if typeof state.expires is "number" && state.expires <= browser.clock
        @remove(name, options)
      else
        path_without_resource = pathname.match(/.*\//) # everything but what trails the last /
        in_domain = cookies[options.domain || hostname] ||= {}
        in_path = in_domain[options.path || path_without_resource] ||= {} 
        in_path[name] = state

    #### cookies(host, path).remove(name, options?)
    #
    # Deletes a cookie.
    #
    # * name -- Cookie name
    # * options -- Options domain, path
    this.remove = (name, options = {})->
      if in_domain = cookies[options.domain || hostname]
        if in_path = in_domain[options.path || pathname]
          delete in_path[name.toLowerCase()]

    #### cookies(host, path).clear()
    #
    # Clears all cookies.
    this.clear = (options = {})->
      if in_domain = cookies[hostname]
        delete in_domain[pathname]

    #### cookies(host, path).update(serialized)
    #
    # Update cookies from serialized form. This method works equally well for
    # the Set-Cookie header and value passed to document.cookie setter.
    #
    # * serialized -- Serialized form
    this.update = (serialized)->
      return unless serialized
      # Handle case where we get array of headers.
      serialized = serialized.join(",") if serialized.constructor == Array
      for cookie in serialized.split(/,(?=[^;,]*=)|,$/)
        unserialized = unserialize(cookie)
        @set(unserialized.name, unserialized.value, unserialized)

    #### cookies(host, path).addHeader(headers)
    #
    # Adds Cookie header suitable for sending to the server.
    this.addHeader = (headers)->
      header = ("#{match[2]}=#{match[3].value}" for match in selected()).join("; ")
      if header.length > 0
        headers.cookie = header

    #### cookies(host, path).pairs => String
    #
    # Returns key/value pairs of all cookies in this domain/path.
    @__defineGetter__ "pairs", ->
      ("#{match[2]}=#{match[3].value}" for match in selected()).join("; ")

    #### cookies(host, path).dump(separator?) => String
    #
    # The default separator is a line break, useful to output when
    # debugging.  If you need to save/load, use comma as the line
    # separator and then call `cookies.update`.
    this.dump = (separator = "\n")->
      (@serialize(browser, match[0], match[1], match[2], match[3]) for match in selected()).join(separator)


# ### document.cookie => String
#
# Returns name=value pairs
core.HTMLDocument.prototype.__defineGetter__ "cookie", -> @parentWindow.cookies.pairs
# ### document.cookie = String
#
# Accepts serialized form (same as Set-Cookie header) and updates cookie from
# new values.
core.HTMLDocument.prototype.__defineSetter__ "cookie", (cookie)-> @parentWindow.cookies.update cookie


exports.use = (browser)->
  cookies = {}
  # Creates and returns cookie access scopes to given host/path.
  access = (hostname, pathname)->
    new Cookies(browser, cookies, hostname, pathname)
  # Add cookies accessor to window: documents need this.
  extend = (window)->
    window.__defineGetter__ "cookies", -> access(@location.hostname, @location.pathname)
  dump = ->
    dump = []
    for domain, in_domain of cookies
      for path, in_path of in_domain
        for name, cookie of in_path
          dump.push serialize(browser, domain, path, name, cookie)
    dump

  return access: access, extend: extend, dump: dump
