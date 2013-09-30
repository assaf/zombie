# See [RFC 2109](http://tools.ietf.org/html/rfc2109.html) and
# [document.cookie](http://developer.mozilla.org/en/document.cookie)
assert  = require("assert")
HTML    = require("jsdom").dom.level3.html
Tough   = require("tough-cookie")
Cookie  = Tough.Cookie


# Lists all available cookies.
module.exports = class Cookies extends Array
  constructor: ->

  # Used to dump state to console (debugging)
  dump: ->
    for cookie in @sort(Tough.cookieCompare)
      process.stdout.write cookie.toString() + "\n"

  # Serializes all selected cookies into a single string.  Used to generate a cookies header.
  #
  # domain - Request hostname
  # path   - Request pathname
  serialize: (domain, path)->
    return @select(domain: domain, path: path)
      .map((cookie)-> cookie.cookieString()).join("; ")

  # Returns all cookies that match the identifier (name, domain and path).
  # This is used for retrieving cookies.
  select: (identifier)->
    cookies = @filter((cookie)-> cookie.TTL() > 0)
    if identifier.name
      cookies = cookies.filter((cookie)-> cookie.key == identifier.name)
    if identifier.path
      cookies = cookies.filter((cookie)-> Tough.pathMatch(identifier.path, cookie.path))
    if identifier.domain
      cookies = cookies.filter((cookie)-> Tough.domainMatch(identifier.domain, cookie.domain))
    return cookies
      .sort((a, b)-> return (b.domain.length - a.domain.length))
      .sort(Tough.cookieCompare)

  # Adds a new cookie, updates existing cookie (same name, domain and path), or
  # deletes a cookie (if expires in the past).
  set: (params)->
    cookie = new Cookie(key: params.name, value: params.value, domain: params.domain || "localhost", path: params.path || "/")
    if params.expires
      cookie.setExpires(params.expires)
    else if params.hasOwnProperty("max-age")
      cookie.setMaxAge(params["max-age"])
    cookie.secure = !!params.secure
    cookie.httpOnly = !!params.httpOnly

    # Delete cookie before setting it, so we only store one cookie (per
    # domain/path/name)
    deleteIfExists = @filter((c)-> c.key == cookie.key && c.domain == cookie.domain && c.path == cookie.path)[0]
    @delete(deleteIfExists)
    if cookie.TTL() > 0
      @push(cookie)
    return

  # Delete the specified cookie.
  delete: (cookie)->
    index = @indexOf(cookie)
    if ~index
      @splice(index, 1)

  # Deletes all cookies.
  deleteAll: ->
    @length = 0

  # Update cookies with HTTP response
  #
  # httpHeader - Value of HTTP Set-Cookie header (string/array)
  # domain     - Set from hostname
  # path       - Set from pathname
  update: (httpHeader, domain, path)->
    # Handle case where we get array of headers.
    if httpHeader.constructor == Array
      httpHeader = httpHeader.join(",")
    for cookie in httpHeader.split(/,(?=[^;,]*=)|,$/)
      cookie = Cookie.parse(cookie)
      if cookie
        cookie.domain ||= domain
        cookie.path   ||= Tough.defaultPath(path)
        # Delete cookie before setting it, so we only store one cookie (per
        # domain/path/name)
        deleteIfExists = @filter((c)-> c.key == cookie.key && c.domain == cookie.domain && c.path == cookie.path)[0]
        @delete(deleteIfExists)
        if cookie.TTL() > 0
          @push(cookie)
    return


# Returns name=value pairs
HTML.HTMLDocument.prototype.__defineGetter__ "cookie", ->
  return @window.browser.cookies.select(domain: @location.hostname, path: @location.pathname)
    .filter((cookie)-> !cookie.httpOnly)
    .map((cookie)-> "#{cookie.key}=#{cookie.value}")
    .join("; ")

# Accepts serialized form (same as Set-Cookie header) and updates cookie from
# new values.
HTML.HTMLDocument.prototype.__defineSetter__ "cookie", (cookie)->
  @window.browser.cookies.update(cookie.toString(), @location.hostname, @location.pathname)
