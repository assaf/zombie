# We switch this directory to instrumented code when running code coverage
# report
process.env.LIB_PATH ||= "lib"
Replay    = require("replay")
Browser   = require("../../#{process.env.LIB_PATH}/zombie")


# Always run in verbose mode on Travis.
Browser.debug = true if process.env.TRAVIS || process.env.DEBUG
Browser.silent = !Browser.debug


# Redirect all HTTP requests to localhost
Replay.fixtures = "#{__dirname}/../replay"
Replay.networkAccess = true
Replay.localhost "host.localhost"


exports.assert  = require("assert")
exports.brains  = require("./brains")
exports.Browser = Browser

