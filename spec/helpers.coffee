# Formidable reads this
process.env.TMP = "#{__dirname}/tmp"

File = require("fs")
Express = require("express")
Zombie = require("../lib/zombie")
Browser = Zombie.Browser

debug = process.env.DEBUG || process.env.TRAVIS


# An express server we use to test the browser.
brains = Express.createServer()
brains.use Express.bodyParser()
brains.use Express.cookieParser()


brains.get "/", (req, res)->
  res.send "<html><title>Tap, Tap</title></html>"

# Prevent sammy from polluting the output. Comment this if you need its
# messages for debugging.
brains.get "/sammy.js", (req, res)->
  File.readFile "#{__dirname}/scripts/sammy.js", (err, data)->
    unless process.env.DEBUG
      data = data + ";window.Sammy.log = function() {}"
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
    brains.listen 3003, ->
      process.nextTick callback
  return # nothing

# Creates a new Vows context that will wait for the HTTP server to be ready,
# then create a new Browser, visit the specified page (url), run all the tests
# and shutdown the HTTP server.
#
# The second argument is the context with all its tests (and subcontexts). The
# topic passed to all tests is the browser window after loading the document.
# However, you can (and often need to) supply a ready function that will be
# called with err and window; the ready function can then call this.callback.
Zombie.wants = (url, context)->
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
    return
  return context

Browser.prototype.wants = (url, options, callback)->
  brains.ready =>
    options.debug = debug
    @visit url, options, (err, browser)=>
      callback err, browser if callback
  return


exports.assert  = require("assert")
exports.brains  = brains
exports.vows    = require("vows")
exports.Zombie  = Zombie
exports.Browser = Browser
