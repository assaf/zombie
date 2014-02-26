# DNS mask allows you to test against local server using a real URL, for
# example, write a test to visit http://example.com that will load a page from
# localhost.

DNS = require("dns")
Net = require("net")


# DNSMask hijacks Node's DNS.resolve and DNS.lookup and returns results based on
# your domain/type -> IP mapping.
class DNSMask
  constructor: ->
    @_domains = {}
    @_lookup      = DNS.lookup
    DNS.lookup    = @lookup.bind(this)
    @_resolve     = DNS.resolve
    DNS.resolve   = @resolve.bind(this)
    @_resolveMx   = DNS.resolve
    DNS.resolveMx = @resolveMx.bind(this)

  # Requests for the given domain will return 127.0.0.1 (or ::1 for IPv6).
  #
  # Use asterisks to map all subdomains, e.g. *.example.com.
  localhost: (domain)->
    @map(domain, "A", "127.0.0.1")
    @map(domain, "AAAA", "::1")

  # Requests for the given domain and type will return the specified address.
  #
  # For example:
  #   map("example.com", "CNAME", "localhost")
  #   map("example.com", "A", "127.0.0.1")
  #   map("example.com", "AAAA", "::1")
  #
  # The record type (A, CNAME, etc) must be uppercase.  You can also call with
  # two arguments, to set A record (IPv4) or AAAA (IPv6).  This is equivalent:
  #   map("example.com", "localhost") # CNAME
  #   map("example.com", "127.0.0.1") # A
  #   map("example.com", "::1")       # AAAA
  #
  # Use asterisks to map all subdomains, e.g. *.example.com.
  map: (domain, type, address)->
    if arguments.length == 2
      address = type
      switch Net.isIP(address)
        when 4
          type = "A"
        when 6
          type = "AAAA"
        else
          type = "CNAME"
    if address
      @_domains[domain] ||= {}
      @_domains[domain][type] = address
    else
      @unmap(domain, type)

  # Remove all mapping for the given domain/type.  With one argument, removes
  # all mapping for the given domain, of any type.
  unmap: (domain, type)->
    if type
      @_domains[domain] ||= {}
      delete @_domains[domain][type]
    else
      delete @_domains[domain]

  # Alternative implementation for Node's DNS.lookup.
  lookup: (domain, family, callback)->
    # With two arguments, second argument is the callback, family is 4 or 6
    if arguments.length == 2
      [family, callback] = [null, family]

    # If lookup called with IP address, resolve that address.
    if Net.isIP(domain)
      setImmediate ->
        callback(null, domain, Net.isIP(domain))
      return

    # First try to resolve CNAME into another domain name, then resolve that to
    # A/AAAA record
    cname = @_find(domain, "CNAME")
    if cname
      domain = cname

    switch family
      when 4
        @resolve domain, "A", (error, addresses)=>
          callback(error, addresses && addresses[0], 4)
      when 6
        @resolve domain, "AAAA", (error, addresses)=>
          callback(error, addresses && addresses[0], 6)
      when null
        @resolve domain, "A", (error, addresses)=>
          if addresses
            callback(error, addresses && addresses[0], 4)
          else
            @resolve domain, "AAAA", (error, addresses)=>
              if addresses
                callback(error, addresses && addresses[0], 6)
              else
                @_lookup domain, family, callback
      else
        throw new Error("Unknown family " + family)

  # Alternative implementation for Node's DNS.resolve.
  resolve: (domain, type, callback)->
    # With two arguments, second argument is the callback, type is 'A'
    if arguments.length == 2
      [type, callback] = ["A", type]
    ip = @_find(domain, type)
    if ip
      setImmediate ->
        callback(null, [ip])
    else
      @_resolve(domain, type, callback)

  # Alternative implementation for Node's DNS.resolveMx.
  resolveMx: (domain, callback)->
    exchange = @_find(domain, "MX")
    if exchange
      setImmediate ->
        callback(null, [exchange])
    else
      @_resolveMx(domain, callback)


  # Returns IP address for the given domain/type.
  _find: (domain, type)->
    # Turn domain into a list of matches, from most to least specific, e.g.
    # 'foo.example.com' turns into:
    #
    # [ 'foo.example.test',
    #   '*.example.test',
    #   '*.test' ]
    parts = domain.split('.')
    domains = [domain, "*." + domain]
    for i in [1...parts.length]
      domains.push("*." + parts[i..parts.length].join('.'))

    return domains.map((pattern)=> @_domains[pattern])
                  .map((domain)=> domain && domain[type])
                  .filter((ip)-> ip)[0]


module.exports = DNSMask

