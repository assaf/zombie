browser = require("./zombie/browser")

# Constructor for a new Browser. Takes no arguments.
exports.Browser = browser.Browser
exports.package = browser.package
exports.version = browser.version

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
  if typeof options is "function"
    [callback, options] = [options, null]
  browser = new exports.Browser(options)
  browser.visit url, callback
  return
