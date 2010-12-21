require.paths.push(__dirname + "/../lib")
fs = require("fs")
express = require("express")
zombie = require("zombie")


# When you run the vows command, it picks all the files in the spec directory
# and attempts to run their exports. If we wanted to export brains or zombie,
# Vows would try to run them, even though they're not test suites. So we hack
# around it by, instead of exporting, assigning them as instance variables on
# the Vows object. And for convenience we also include assert in there.
vows = require("vows")
vows.vows = vows
vows.assert = require("assert")

# Hack Vows console to figure out when Vows is done running tests and shut down
# the Web server.
vows.console = require("vows/console")
result = vows.console.result
vows.console.result = (results)->
  brains.close() if brains.active
  result.call vows.console, results

# An Express server we use to test the browser.
brains = express.createServer()
brains.use express.bodyDecoder()
brains.use express.cookieDecoder()


# Patch Express to do the right thing when setting a cookie: create single
# header with multiple cookie values separated by comma.
require("http").ServerResponse.prototype.cookie = (name, val, options)->
  cookie = require("connect/utils").serializeCookie(name, val, options)
  if @headers['Set-Cookie']
    @headers['Set-Cookie'] += ", #{cookie}"
  else
    @headers['Set-Cookie'] = cookie
   

brains.get "/", (req, res)->
  res.send "<html><title>Tap, Tap</title></html>"
brains.get "/jquery.js", (req, res)->
  fs.readFile "#{__dirname}/.scripts/jquery.js", (err, data)-> res.send data
brains.get "/sammy.js", (req, res)->
  fs.readFile "#{__dirname}/.scripts/sammy.js", (err, data)->
    # Prevent sammy from polluting the output. Comment this if you need its
    # messages for debugging.
    data = "console.log = function() { };" + data
    res.send data
brains.ready = (callback)->
  if @active
    process.nextTick callback
  else
    brains.listen 3003, ->
      @active = true
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
    new zombie.Browser().wants url, (err, browser)=>
      if topic
        topic.call this, browser, browser.window
      else
        browser.wait @callback
    return
  return context

zombie.Browser.prototype.wants = (url, callback)->
  brains.ready =>
    @visit url, (err, browser)=>
      callback err, this
  return


vows.zombie = zombie
vows.brains = brains
