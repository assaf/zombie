WebSocket = require("ws")

exports.use = ->
  # Add WebSocket constructor to window.
  extend = (window)->
    window.WebSocket = (url, proto) ->
      # Make sure that the origin is set correctly
      loc = window.location
      opts = { origin: "#{loc.protocol}//#{loc.hostname}", protocol: proto }
      if window.location.port
        opts.origin += ":" + window.location.port
      new WebSocket(url, opts)
  return extend: extend
