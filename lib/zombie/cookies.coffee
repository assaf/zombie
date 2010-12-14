core = require("jsdom").dom.level3.core


exports.cookies = (browser)->
  cookies = []
  # TODO
  # name -- Cookie name
  # options -- Further identify cookie by domain and path
  # Returns value of cookie or null
  @get = (name, options = {})->
    name = name.toLowerCase()
    domain = options.domain || browser.location.hostname
    path = options.path || browser.location.pathname
    for cookie in cookies
      if match(cookie, name, domain, path)
        return cookie.value
    return
  # TODO
  # name -- Cookie name
  # value -- Cookie value
  # options -- Further specify domain, path and expires
  @set = (name, value, options = {})->
    name = name.toLowerCase()
    value = value.toString()
    domain = options.domain || browser.location.hostname
    path = options.path || "/"
    if options.expires
      expires = options.expires.getTime()
      if expires < browser.clock
        @delete name, { domain: domain, path: path }
        return
    for cookie in cookies
      if match(cookie, name, domain, path)
        cookie.value = value
        return
    cookies.push { name: name, value: value, domain: domain, path: path, expires: expires }
  # TODO
  # name -- Cookie name
  # options -- Further identify cookie by domain and path
  # Returns value of cookie or null
  @delete = (name, options = {})->
    name = name.toLowerCase()
    domain = options.domain || browser.location.hostname
    path = options.path || "/"
    for i in [0...cookies.length]
      if match(cookie, name, domain, path)
        cookies.splice i,1
        return

  # Return all cookies that match the given hostname and path.
  #
  # hostname -- Hostname of page
  # path -- Path of page
  # Returns array of cookies
  select = (hostname, path)->
    cookies.filter (cookie)->
      return false if cookie.expires && cookie.expires < browser.clock
      return false if cookie.path && path.indexOf(cookie.path) != 0
      while hostname.length > 1
        return true if hostname == cookie.domain
        hostname = hostname.replace(/(^|\.)[^\.]\./, ".")
      return false

  # Return header cookies that match the given hostname and path.
  #
  # hostname -- Hostname of page
  # path -- Path of page
  # Returns array of cookie strings
  headers = (hostname, path)->
    select.map (cookie)->
      str = "#{cookie.name}=#{cookie.value}; domain=#{cookie.domain}"
      str = str + "; path=#{cookie.path}" if cookie.path
      str = str + "; expires=#{new Date(cookie.expires).toGMTString()}" if cookie.expires
      return str

  # TODO
  # hostname -- Hostname of page
  # path -- Path of page
  # cookie -- Cookie string
  update = (hostname, path, cookie)->
    parts = cookie.split(/\s*;\s*/)
    [name, value] = parts[0].split(/=/)
    options = parts[1...parts.length].reduce({}, (m, part)->
      [k,v] = part.split(/=/)
      m[k] = v
      m
    )
    return if options.path && !path.indexOf(options.path) == 0
    options.expires = Date.parse(options.expires) if options.expires
    if options.domain
      while hostname.length > 1
        return unless hostname == cookie.domain
        hostname = hostname.replace(/(^|\.)[^\.]\./, ".")
    else
      options.domain = hostname
    @set name, value, options

  @attach = (window)->
    window.__defineGetter__ "cookies", ->
      select @location.hostname, @location.pathname
    window.__defineSetter__ "cookies", (cookie)->
      update @location.hostname, @location.pathname, cookie
  return this

# TODO
core.HTMLDocument.prototype.__defineGetter__ "cookie", ->
  @parentWindow.cookies.map( (cookie)-> "#{cookie.name}=#{cookie.value}").join("; ")
core.HTMLDocument.prototype.__defineSetter__ "cookie", (cookie)-> @parentWindow.cookies = cookie
