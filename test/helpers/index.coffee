# We switch this directory to instrumented code when running code coverage
# report
process.env.LIB_PATH ||= "src"
Replay    = require("replay")
Browser   = require("../../#{process.env.LIB_PATH}/zombie")


# Always run in verbose mode on Travis.
Browser.default.debug = !!(process.env.TRAVIS || process.env.DEBUG)
Browser.default.silent = !Browser.default.debug
Browser.default.site = "localhost:3003"


# Redirect all HTTP requests to localhost
Replay.fixtures = "#{__dirname}/../replay"
Replay.networkAccess = true
Replay.localhost "host.localhost"


module.exports =
  assert:   require("assert")
  brains:   require("./brains")
  Browser:  Browser
