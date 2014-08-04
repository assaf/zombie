HTTP = require("http")


class PortMap
  constructor: ->
    @_ports = {}
    @_http = HTTP.request
    HTTP.request = @_request.bind(this)

  map: (hostname, port)->
    @_ports[hostname] = port

  unmap: (hostname)->
    delete @_ports.hostname

  _request: (options, callback)->
    hostname = options.hostname || (options.host && options.host.split(":")[0]) || "localhost"
    port     = options.port     || (options.host && options.host.split(":")[1]) || 80
    if port == 80
      mapped = @_find(hostname)
      if mapped
        options = Object.create(options)
        options.hostname = hostname
        options.port     = mapped
    return @_http(options, callback)

  _find: (domain)->
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

    return domains.map((pattern)=> @_ports[pattern]).filter((port)-> port)[0]


module.exports = PortMap
