{ browser: browser } = require("zombie")


exports.server = server = require("express").createServer()
server.get "/", (req, res)->
  res.send "<html><title>Little Red</title></html>"
server.get "/jquery.js", (req, res)->
  fs.readFile "#{__dirname}/data/jquery.js", (err, data)-> res.send data
server.ready = (callback)->
  if @_waiting
    @_waiting.push callback
  else if @_active
    ++@_active
    callback()
  else
    @_waiting = [callback]
    server.listen 3003, ->
      @_active = @_waiting.length
      @_waiting.forEach (callback)-> callback()
      @_waiting = null
  return # nothing
server.done = -> @close() if --@_active == 0


# Creates a new Vows context that will wait for the HTTP server to be ready,
# then create a new Browser, visit the specified page (url), run all the tests
# and shutdown the HTTP server.
#
# The second argument is the context with all its tests (and subcontexts). The
# topic passed to all tests is the browser window after loading the document.
# However, you can (and often need to) supply a ready function that will be
# called with err and window; the ready function can then call this.callback.
exports.visit = (url, context)->
  context ||= {}
  context.topic = ->
    ready = context.ready
    delete context.ready
    server.ready =>
      browser.open "http://localhost:3003/", (err, window)=>
        if ready
          ready.apply this, [err, window]
        else
          @callback err, window
    return
  context.teardown = -> server.done()
  return context
