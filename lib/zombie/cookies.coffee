# Cookies.
URL = require("url")
core = require("jsdom").dom.level3.core

# ## browser.cookies
#
# Maintains cookies for a Browser instance.
#
# See [RFC 2109](http://tools.ietf.org/html/rfc2109.html) and
# [document.cookie](http://developer.mozilla.org/en/document.cookie)
class Cookies
  constructor: (browser)->
    # Cookies are mapped by domain first, path second.
    cookies = {}

    # Serialize cookie object into RFC2109 representation.
    serialize = (domain, path, name, cookie)->
      str = "#{name}=#{cookie.value}; domain=#{domain}; path=#{path}"
      str = str + "; max-age=#{cookie.expires - browser.time}" if cookie.expires
      str = str + "; secure" if cookie.secure
      str

    # Return all the cookies that match the given hostname/path, from most
    # specific to least specific. Returns array of arrays, each item is
    # [domain, path, name, cookie].
    filter = (url)->
      matching = []
      hostname = url.hostname
      pathname = url.pathname
      pathname = "/" if !pathname || pathname == ""
      for domain, inDomain of cookies
        # Ignore cookies that don't match the exact hostname, or .domain.
        continue unless hostname == domain || (domain.charAt(0) == "." && hostname.lastIndexOf(domain) + domain.length == hostname.length)
        # Ignore cookies that don't match the path.
        for path, inPath of inDomain
          continue unless pathname.indexOf(path) == 0
          for name, cookie of inPath
            # Delete expired cookies.
            if inPath.expires && inPath.expires <= browser.time
              delete inPath[name]
            else
              matching.push [domain, path, name, cookie]
      # Sort from most specific to least specified. Only worry about path
      # (longest is more specific)
      matching.sort (a,b) -> a[1].length - b[1].length

    # Cookie header values are (supposed to be) quoted. This function strips
    # double quotes aroud value, if it finds both quotes.
    dequote = (value)-> value.replace(/^"(.*)"$/, "$1")


    #### cookies.get name, url? => String
    #
    # Returns the value of a cookie. Using cookie name alone, returns first
    # cookie to match the current browser.location.
    #
    # name -- Cookie name
    # url -- Uses hostname/pathname to filter cookies
    # Returns cookie value if known
    this.get = (name, url = browser.location)->
      url = URL.parse(url)
      for match in filter(url)
        return match[3].value if match[2] == name
    
    #### cookies.set name, value, options?
    #
    # Sets a cookie (deletes if expires/max-age is in the past). You can specify
    # the cookie domain and path as part of the options object, or have it
    # default to the current browser.location.
    #
    # name -- Cookie name
    # value -- Cookie value
    # options -- Options domain, path, max-age/expires and secure
    this.set = (name, value, options = {})->
      name = name.toLowerCase()
      value = value.toString()
      options.domain ||= browser.location?.hostname
      throw new Error("No location for cookie, please call with options.domain") unless options.domain
      options.path ||= browser.location?.pathname
      options.path = "/" if !options.path || options.path == ""
      if options.expires
        expires = options.expires.getTime()
      else
        maxage = options["max-age"]
        expires = browser.time + maxage if typeof maxage is "number"
      if expires && expires <= browser.time
        inDomain = cookies[options.domain]
        inPath = inDomain[options.path] if inDomain
        delete inPath[name] if inPath
      else
        inDomain = cookies[options.domain] ||= {}
        inPath = inDomain[options.path] ||= {}
        inPath[name] = { value: value, expires: expires, secure: !!options.secure }
   
    #### cookies.delete name, options?
    #
    # Deletes a cookie. You can specify # the cookie domain and path as part of
    # the options object, or have it # default to the current browser.location.
    #
    # name -- Cookie name
    # options -- Optional domain and path
    this.delete = (name, options = {})->
      @set name, "", { expires: 0, domain: options.domain, path: options.path }
 
    #### cookies.dump => String
    #
    # Returns all the cookies in serialized form, one on each line.
    this.dump = ->
      serialized = []
      for domain, inDomain of cookies
        for path, inPath of inDomain
          for name, cookie of inPath
            serialized.push serialize(domain, path, name, cookie)
      serialized.join("\n")

    # Returns key/value pairs of all cookies that match a given url.
    this._pairs = (url)->
      set = []
      for match in filter(url)
        set.push "#{match[2]}=#{match[3].value}"
      set.join("; ")

    # Update cookies from serialized form. This method works equally well for
    # the Set-Cookie header and value passed to document.cookie setter.
    #
    # url -- Document location or request URL
    # serialized -- Serialized form
    this._update = (url, serialized)->
      return unless serialized
      for cookie in serialized.split(/,(?=[^;,]*=)|,$/)
        fields = cookie.split(/;+/)
        first = fields[0].trim()
        [name, value] = first.split(/\=/, 2)

        options = {}
        for field in fields
          [key, val] = field.trim().split(/\=/, 2)
          # val = dequote(val.trim()) if val
          switch key.toLowerCase()
            when "domain"   then options.domain = dequote(val)
            when "path"     then options.path   = dequote(val)
            when "expires"  then options.expires = new Date(dequote(val))
            when "max-age"  then options["max-age"] = parseInt(dequote(val), 10)
            when "secure"   then options.secure = true
        options.domain  ||= url.hostname
        options.path    ||= url.pathname.replace(/%[^\/]*$/, "")
        options.secure  ||= false
        @set name, dequote(value), options

    # Returns Cookie header suitable for sending to the server. Needs request
    # URL to figure out which cookies to send.
    this._header = (url)->
      "$Version=\"1\";" + ("#{match[2]}=\"#{match[3].value}\";$Path=\"#{match[1]}\"" for match in filter(url)).join(";")


# ### document.cookie => String
#
# Returns name=value; pairs
core.HTMLDocument.prototype.__defineGetter__ "cookie", -> @parentWindow.cookies._pairs(@parentWindow.location)
# ### document.cookie = String
#
# Accepts serialized form (same as Set-Cookie header) and updates cookie from
# new values.
core.HTMLDocument.prototype.__defineSetter__ "cookie", (cookie)-> @parentWindow.cookies._update cookie


# Add cookies support to browser. Returns Cookies object.
exports.use = (browser)->
  new Cookies(browser)
