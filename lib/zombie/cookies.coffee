# See [RFC 2109](http://tools.ietf.org/html/rfc2109.html) and
# [document.cookie](http://developer.mozilla.org/en/document.cookie)
URL = require("url")
HTML = require("jsdom").dom.level3.html


# Serialize cookie object into RFC2109 representation.
serialize = (domain, path, name, cookie)->
  str = "#{name}=#{cookie.value}; Domain=#{domain}; Path=#{path}"
  if cookie.expires
    str += "; Max-Age=#{cookie.expires - +new Date}"
  if cookie.secure
    str += "; Secure"
  if cookie.httpOnly
    str += "; HttpOnly"
  str

# Deserialize a cookie
deserialize = (serialized)->
  fields = serialized.split(/;+/)
  first = fields[0].trim()
  [_, name, value] = first.match(/(.*?)=(.*)/)
  value = value.replace(/^"(.*)"$/, "$1")

  cookie = { name: name, value: value }
  for field in fields
    [key, val] = field.trim().split(/\=/, 2)
    switch key.toLowerCase()
      when "domain"   then cookie.domain      = dequote(val)
      when "path"     then cookie.path        = dequote(val).replace(/%[^\/]*$/, "")
      when "expires"  then cookie.expires     = new Date(dequote(val))
      when "max-age"  then cookie['max-age']  = parseInt(dequote(val), 10)
      when "secure"   then cookie.secure      = true
      when "httponly" then cookie.httpOnly    = true
  return cookie

# Cookie header values are (supposed to be) quoted. This function strips
# double quotes aroud value, if it finds both quotes.
dequote = (value)->
  value.replace(/^"(.*)"$/, "$1")

# Determines if domain matches hostname.
domainMatch = (domain, hostname)->
  return domain == hostname ||
    (domain.charAt(0) == "." && domain.substring(1) == hostname.replace(/^[^.]+\./, ""))


# Domain/path specific scope around the global cookies collection.
class Access
  constructor: (@_cookies, @_hostname, @_pathname)->
    if !@_pathname || @_pathname == ""
      @_pathname = "/"

  # Return all the cookies that match the given hostname/path, from most
  # specific to least specific. Returns array of arrays, each item is
  # [domain, path, name, cookie].
  _selected: ->
    matching = []
    for domain, in_domain of @_cookies
      # Ignore cookies that don't match the exact hostname, or .domain.
      continue unless domainMatch(domain, @_hostname)
      # Ignore cookies that don't match the path.
      for path, in_path of in_domain
        continue unless @_pathname.indexOf(path) == 0
        for name, cookie of in_path
          # Delete expired cookies.
          if typeof cookie.expires == "number" && cookie.expires <= +new Date
            delete in_path[name]
          else
            matching.push [domain, path, name, cookie]
    # Sort from most specific to least specified. Only worry about path
    # (longest is more specific)
    return matching.sort((a,b) -> a[1].length - b[1].length)

  # Returns all the cookies for this domain/path.
  all: ->
    cookies = {}
    for match in @_selected()
      cookies[match[2]] = match[3]
    return cookies

  # Returns the value of a cookie.
  #
  # * name -- Cookie name
  # * Returns cookie value if known
  get: (name)->
    for match in @_selected()
      if match[2] == name
        return match[3].value

  # Sets a cookie (deletes if expires/max-age is in the past).
  #
  # * name -- Cookie name
  # * value -- Cookie value
  # * options -- Options max-age, expires, secure, domain, path
  set: (name, value, options = {})->
    if options.domain && !domainMatch(options.domain, @_hostname)
      return

    name = name
    state = { value: value.toString() }
    if options.expires
      state.expires = options.expires.getTime()
    else
      maxage = options["max-age"]
      if typeof maxage == "number"
        state.expires = +new Date + maxage
    state.secure = !!options.secure
    state.httpOnly = !!options.httpOnly

    if typeof state.expires == "number" && state.expires <= +new Date
      @remove(name, options)
    else
      path_without_resource = @_pathname.match(/.*\//) # everything but what trails the last /
      in_domain = @_cookies[options.domain || @_hostname] ||= {}
      in_path = in_domain[options.path || path_without_resource] ||= {}
      in_path[name] = state

  # Deletes a cookie.
  #
  # * name -- Cookie name
  # * options -- Options domain, path
  remove: (name, options = {})->
    in_domain = @_cookies[options.domain || @_hostname]
    if in_domain
      in_path = in_domain[options.path || @_pathname]
      if in_path
        delete in_path[name]

  # Clears all cookies.
  clear: (options = {})->
    in_domain = @_cookies[@_hostname]
    if in_domain
      delete in_domain[@_pathname]

  # Update cookies from serialized form. This method works equally well for
  # the Set-Cookie header and value passed to document.cookie setter.
  #
  # * serialized -- Serialized form
  update: (serialized)->
    return unless serialized
    # Handle case where we get array of headers.
    serialized = serialized.join(",") if serialized.constructor == Array
    for cookie in serialized.split(/,(?=[^;,]*=)|,$/)
      cookie = deserialize(cookie)
      @set cookie.name, cookie.value, cookie

  # Adds Cookie header suitable for sending to the server.
  addHeader: (headers)->
    header = ("#{match[2]}=#{match[3].value}" for match in @_selected()).join("; ")
    if header.length > 0
      headers.cookie = header

  # The default separator is a line break, useful to output when
  # debugging.  If you need to save/load, use comma as the line
  # separator and then call `cookies.update`.
  dump: (separator = "\n")->
    return (serialize(match[0], match[1], match[2], match[3]) for match in @_selected()).join(separator)


class Cookies
  constructor: ->
    @_cookies = {}

  # Creates and returns cookie access scopes to given host/path.
  access: (hostname, pathname)->
    return new Access(@_cookies, hostname, pathname)

  # Add cookies accessor to window: documents need this.
  extend: (window)->
    Object.defineProperty window, "cookies",
      get: ->
        return @browser.cookies(@location.hostname, @location.pathname)

  # Used to dump state to console (debuggin)
  dump: ->
    serialized = []
    for domain, in_domain of @_cookies
      for path, in_path of in_domain
        for name, cookie of in_path
          serialized.push serialize(domain, path, name, cookie)
    return serialized

  # browser.saveCookies uses this
  save: ->
    serialized = ["# Saved on #{new Date().toISOString()}"]
    for domain, in_domain of @_cookies
      for path, in_path of in_domain
        for name, cookie of in_path
          serialized.push serialize(domain, path, name, cookie)
    return serialized.join("\n") + "\n"

  # browser.loadCookies uses this
  load: (serialized)->
    for line in serialized.split(/\n+/)
      line = line.trim()
      continue if line[0] == "#" || line == ""
      cookie = deserialize(line)
      new Access(@_cookies, cookie.domain, cookie.path).set(cookie.name, cookie.value, cookie)


# Returns name=value pairs
HTML.HTMLDocument.prototype.__defineGetter__ "cookie", ->
  cookies = ("#{name}=#{cookie.value}" for name, cookie of @parentWindow.cookies.all() when !cookie.httpOnly)
  return cookies.join("; ")

# Accepts serialized form (same as Set-Cookie header) and updates cookie from
# new values.
HTML.HTMLDocument.prototype.__defineSetter__ "cookie", (cookie)->
  @parentWindow.cookies.update cookie


module.exports = Cookies
