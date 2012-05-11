# See [RFC 2109](http://tools.ietf.org/html/rfc2109.html) and
# [document.cookie](http://developer.mozilla.org/en/document.cookie)
HTML    = require("jsdom").dom.level3.html
Tough   = require("tough-cookie")
Cookie  = Tough.Cookie


# Domain/path specific scope around the global cookies collection.
class Access
  constructor: (@_cookies, domain, path)->
    @domain = Tough.canonicalDomain(domain)
    @path   = path || "/"

  # Returns all the cookies for this domain/path.
  all: ->
    return @_cookies.all().filter((cookie)=>
      return Tough.domainMatch(@domain, cookie.domain) && Tough.pathMatch(@path, cookie.path) && cookie.TTL() > 0
    ).sort(Tough.cookieCompare)

  # Returns the value of a cookie.
  #
  # * name -- Cookie name
  # * Returns cookie value if known
  get: (name)->
    sorted = @all()
    for cookie in sorted
      if cookie.key == name
        return cookie.value
    return

  # Sets a cookie (deletes if expires/max-age is in the past).
  #
  # * name -- Cookie name
  # * value -- Cookie value
  # * options -- Options max-age, expires, secure, domain, path
  set: (name, value, options = {})->
    cookie = new Cookie(key: name, value: value, domain: options.domain || @domain, path: options.path || @path)
    if options.expires
      cookie.setExpires(options.expirs)
    else if options.hasOwnProperty("max-age")
      cookie.setMaxAge(options["max-age"])
    cookie.secure = !!options.secure
    cookie.httpOnly = !!options.httpOnly

    # Delete cookie before setting it, so we only store one cookie (per
    # domain/path/name)
    @_cookies.filter((c)=> !(cookie.key == c.key && cookie.domain == c.domain && cookie.path == c.path) )
    if Tough.domainMatch(cookie.domain, @domain) && Tough.pathMatch(cookie.path, @path) && cookie.TTL() > 0
      @_cookies.push cookie

  # Deletes a cookie.
  #
  # * name -- Cookie name
  remove: (name)->
    @_cookies.filter((cookie)=> !(cookie.key == name && cookie.domain == @domain && cookie.path == @path) )

  # Clears all cookies.
  clear: ->
    @_cookies.filter((cookie)=> !(cookie.domain == @domain && cookie.path == @path) )

  # Update cookies from serialized form. This method works equally well for
  # the Set-Cookie header and value passed to document.cookie setter.
  #
  # * serialized -- Serialized form
  update: (serialized)->
    return unless serialized
    # Handle case where we get array of headers.
    serialized = serialized.join(",") if serialized.constructor == Array
    for cookie in serialized.split(/,(?=[^;,]*=)|,$/)
      cookie = Cookie.parse(cookie)
      cookie.domain ||= @domain
      cookie.path   ||= @path
      # Delete cookie before setting it, so we only store one cookie (per
      # domain/path/name)
      @_cookies.filter((c)-> !(cookie.key == c.key && cookie.domain == c.domain && cookie.path == c.path) )
      if Tough.domainMatch(@domain, cookie.domain) && Tough.pathMatch(@path, cookie.path) && cookie.TTL() > 0
        @_cookies.push cookie

  # Adds Cookie header suitable for sending to the server.
  addHeader: (headers)->
    header = (cookie.cookieString() for cookie in @all()).join("; ")
    if header.length > 0
      headers.cookie = header

  # The default separator is a line break, useful to output when
  # debugging.  If you need to save/load, use comma as the line
  # separator and then call `cookies.update`.
  dump: (separator = "\n")->
    return (cookie.toString() for cookie in @all()).join(separator)

  toString: ->
    return (cookie.toString() for cookie in @all()).join("\n")


class Cookies
  constructor: ->
    @_cookies = []

  # Creates and returns cookie access scopes to given host/path.
  access: (hostname, pathname)->
    return new Access(this, hostname, pathname)

  # Add cookies accessor to window: documents need this.
  extend: (window)->
    Object.defineProperty window, "cookies",
      get: ->
        return @browser.cookies(@location.hostname, @location.pathname)

  # Used to dump state to console (debugging)
  dump: ->
    for cookie in @_cookies.sort(Tough.cookieCompare)
      process.stdout.write cookie.toString() + "\n"

  # browser.saveCookies uses this
  save: ->
    serialized = ["# Saved on #{new Date().toISOString()}"]
    for cookie in @_cookies.sort(Tough.cookieCompare)
      serialized.push cookie.toString()
    return serialized.join("\n") + "\n"

  # browser.loadCookies uses this
  load: (serialized)->
    for line in serialized.split(/\n+/)
      line = line.trim()
      continue if line[0] == "#" || line == ""
      @_cookies.push Cookie.parse(line)

  filter: (fn)->
    @_cookies = @_cookies.filter(fn)

  push: (cookie)->
    @_cookies.push cookie

  all: ->
    @_cookies.slice()


# Returns name=value pairs
HTML.HTMLDocument.prototype.__defineGetter__ "cookie", ->
  cookies = ("#{cookie.key}=#{cookie.value}" for cookie in @parentWindow.cookies.all() when !cookie.httpOnly)
  return cookies.join("; ")

# Accepts serialized form (same as Set-Cookie header) and updates cookie from
# new values.
HTML.HTMLDocument.prototype.__defineSetter__ "cookie", (cookie)->
  @parentWindow.cookies.update cookie


module.exports = Cookies
