zombie = require("./zombie/browser")

# Constructor for a new Browser. Takes no arguments.
exports.Browser = zombie.Browser
exports.package = zombie.package
exports.version = zombie.version


# ### zombie.visit(url, callback)
# ### zombie.visit(url, options, callback)
#
# Creates a new Browser, opens window to the URL and calls the callback when
# done processing all events.
#
# For example:
#     zombie = require("zombie")
#
#     vows.describe("Brains").addBatch(
#       "seek":
#         topic: ->
#           zombie.browse "http://localhost:3000/brains", @callback
#       "should find": (browser)->
#         assert.ok browser.html("#brains")[0]
#     ).export(module);
#
# * url -- URL of page to open
# * options -- Initialize the browser with these options
# * callback -- Called with error, browser
exports.visit = (url, options, callback)->
  new zombie.Browser(options).visit(url, options, callback)


# ### listen port, callback
# ### listen socket, callback
# ### listen callback
#
# Ask Zombie to listen on the specified port for requests.  The default
# port is 8091, or you can specify a socket name.  The callback is
# invoked once Zombie is ready to accept new connections.
exports.listen = (port, callback)->
  require("./zombie/protocol").listen(port, callback)
