Assert    = require("./assert")
Resources = require("./resources")
Browser   = require("./browser")
Path      = require("path")


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
  if arguments.length == 2
    [options, callback] = [null, options]
  browser = Browser.create(options)
  if callback
    browser.visit url, options, (error)->
      callback(error, browser)
  else
    return browser.visit(url, options).then(-> browser);


# ### listen port, callback
# ### listen socket, callback
# ### listen callback
#
# Ask Zombie to listen on the specified port for requests.  The default
# port is 8091, or you can specify a socket name.  The callback is
# invoked once Zombie is ready to accept new connections.
listen = (port, callback)->
  require("./zombie/protocol").listen(port, callback)


Browser.listen    = listen
Browser.visit     = visit
Browser.Assert    = Assert
Browser.Resources = Resources


# Default to debug mode if environment variable `DEBUG` is set.
Browser.debug = !!process.env.DEBUG

# Export the globals from browser.coffee
module.exports = Browser
