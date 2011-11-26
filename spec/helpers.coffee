#require.paths.unshift __dirname + "/../node_modules"
fs = require("fs")
express = require("express")
zombie = require("../lib/zombie")
Browser = zombie.Browser

debug = process.env.DEBUG || process.env.TRAVIS


# When you run the vows command, it picks all the files in the spec directory
# and attempts to run their exports. If we wanted to export brains or zombie,
# Vows would try to run them, even though they're not test suites. So we hack
# around it by, instead of exporting, assigning them as instance variables on
# the Vows object. And for convenience we also include assert in there.
vows = require("vows")
vows.vows = vows
vows.assert = require("assert")

process.on "exit", ->
  if brains.active
    brains.close()

# An Express server we use to test the browser.
brains = express.createServer()
brains.use express.bodyParser()
brains.use express.cookieParser()


brains.get "/", (req, res)->
  res.send "<html><title>Tap, Tap</title></html>"
# Prevent sammy from polluting the output. Comment this if you need its
# messages for debugging.
brains.get "/sammy.js", (req, res)->
  fs.readFile "#{__dirname}/scripts/sammy.js", (err, data)->
    data = data + ";window.Sammy.log = function() {}"
    res.send data
brains.get "/jquery.js", (req, res)->
  res.redirect "/jquery-1.6.3.js"
fs.readdirSync(__dirname + "/scripts", "*.js").forEach (script)->
  brains.get "/#{script}", (req, res)->
    fs.readFile "#{__dirname}/scripts/#{script}", (err, data)-> res.send data

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
zombie.wants = (url, context)->
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
      callback err, this if callback
  return


vows.zombie = zombie
vows.Browser = zombie.Browser
vows.brains = brains
