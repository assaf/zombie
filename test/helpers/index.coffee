Replay    = require("replay")
Browser   = require("../../lib/zombie")


# Always run in verbose mode on Travis.
Browser.debug = true if process.env.TRAVIS
Browser.silent = !Browser.debug


# Redirect all HTTP requests to localhost
Replay.fixtures = "#{__dirname}/../replay"
Replay.networkAccess = true
Replay.localhost "host.localhost"


exports.assert  = require("assert")
exports.brains  = require("./brains")
exports.Browser = Browser

