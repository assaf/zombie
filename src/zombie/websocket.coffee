WebSocket = require('websocket-client').WebSocket

exports.use = ->
	# Add XHR constructor to window.
	extend = (window)->
		window.WebSocket = (url, proto, opts) -> new WebSocket(url, proto, opts)
	return extend: extend
