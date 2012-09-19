Browser = require("./browser")
Path    = require("path")


# Make sure Contextify is available to JSDOM
###
try
  contextify = Path.resolve(require.resolve("jsdom"), "../../node_modules/contextify")
  require contextify
catch ex
  throw new Error("To use Zombie, Contextify must be installed as a dependency of JSDOM (not Zombie itself)")
###


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
visit = (url, options, callback)->
  new Browser(options).visit(url, options, callback)


# ### listen port, callback
# ### listen socket, callback
# ### listen callback
#
# Ask Zombie to listen on the specified port for requests.  The default
# port is 8091, or you can specify a socket name.  The callback is
# invoked once Zombie is ready to accept new connections.
listen = (port, callback)->
  require("./zombie/protocol").listen(port, callback)


Browser.listen  = listen
Browser.visit   = visit

# Default to debug mode if environment variable `DEBUG` is set.
Browser.debug = !!process.env.DEBUG
Browser.Browser = Browser

# Export the globals from browser.coffee
module.exports = Browser
