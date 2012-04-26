Replay    = require("replay")
Browser   = require("../../lib/zombie.js")


# Always run in verbose mode on Travis.
Browser.debug = true if process.env.TRAVIS
Browser.silent = !Browser.debug


# Redirect all HTTP requests to localhost
Replay.fixtures = "#{__dirname}/../replay"
Replay.networkAccess = true
Replay.localhost "host.localhost"
Replay.ignore "mt0.googleapis.com", "mt1.googleapis.com"


exports.assert  = require("assert")
exports.brains  = require("./brains")
exports.Browser = Browser

