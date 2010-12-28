# Constructor for a new Browser. Takes no arguments.
exports.Browser = require("./zombie/browser").Browser


# ### zombie.visit(url, callback)
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
# * callback -- Called with error, browser
exports.visit = (url, callback)->
  browser = new exports.Browser
  browser.visit url, callback
  return

# ### zombie.version : String
try
  exports.package = JSON.parse(require("fs").readFileSync("package.json"))
  exports.version = exports.package.version
catch err
  console.log err
