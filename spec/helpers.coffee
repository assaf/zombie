DNS       = require("dns")
Express   = require("express")
WebSocket = require("ws")
File      = require("fs")
Path      = require("path")
Browser   = require("../lib/zombie.js")


# Always run in verbose mode on Travis.
Browser.debug = true if process.env.TRAVIS
Browser.silent = !Browser.debug


# Redirect all HTTP requests to localhost
DNS.lookup = (domain, callback)->
  callback null, "127.0.0.1", 4


# An express server we use to test the browser.
brains = Express.createServer()
brains.use Express.bodyParser()
brains.use Express.cookieParser()
wss = new WebSocket.Server({ server: brains })


brains.get "/", (req, res)->
  res.send "<html><title>Tap, Tap</title></html>"

wss.on "connection", (client)->
  client.send "Hello"

# Prevent sammy from polluting the output. Comment this if you need its
# messages for debugging.
brains.get "/sammy.js", (req, res)->
  File.readFile "#{__dirname}/scripts/sammy.js", (err, data)->
    #    unless process.env.DEBUG
    #  data = data + ";window.Sammy.log = function() {}"
    res.send data

brains.get "/jquery.js", (req, res)->
  res.redirect "/jquery-1.7.1.js"
brains.get "/jquery-:version.js", (req, res)->
  version = req.params.version
  File.readFile "#{__dirname}/scripts/jquery-#{version}.js", (err, data)->
    res.send data


brains.ready = (callback)->
  if @active
    process.nextTick callback
  else
    @active = true
    brains.listen 3003, callback
  return # nothing

# Creates a new Vows context that will wait for the HTTP server to be ready,
# then create a new Browser, visit the specified page (url), run all the tests
# and shutdown the HTTP server.
#
# The second argument is the context with all its tests (and subcontexts). The
# topic passed to all tests is the browser window after loading the document.
# However, you can (and often need to) supply a ready function that will be
# called with err and window; the ready function can then call this.callback.
Browser.wants = (url, context)->
  topic = context.topic
  context.topic = ->
    browser = new Browser
    browser.wants url, {}, (err, rest...)=>
      if topic
        try
          value = topic.apply(this, rest)
          if value
            @callback null, value
        catch err
          @callback err
      else
        throw err if err
        browser.wait @callback
    return # nothing
  return context

Browser.prototype.wants = (url, options, callback)->
  if !callback && typeof options == "function"
    [options, callback] = [null, options]
  brains.ready =>
    @visit url, options, (err, browser)=>
      callback err, browser if callback
  return # nothing


exports.assert  = require("assert")
exports.brains  = brains
exports.Vows    = require("vows")
exports.Browser = Browser
