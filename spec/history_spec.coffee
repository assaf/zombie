require.paths.unshift(__dirname)
fs = require("fs")
vows = require("vows")
assert = require("assert")
browser = require("browser")
jsdom = require("jsdom")


server = require("express").createServer()
server.get "/jquery.js", (req, res)->
  fs.readFile "#{__dirname}/data/jquery.js", (err, data)-> res.send data
server.get "/", (req, res)->
  res.send """
           <html>
             <title>Little Red</title>
           </html>"
           """
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
visit = (url, context)->
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
  

vows.describe("History").addBatch({
  "new window":
    topic: -> browser.new().window
    "should start out empty": (window)-> assert.length window.history, 0
    "should start out with no location": (window)-> assert.isUndefined window.location.href
    "go forward":
      topic: (window)->
        window.history.forward()
        window
      "should have no effect": (window)->
        assert.length window.history, 0
        assert.isUndefined window.location.href
    "go backwards":
      topic: (window)->
        window.history.back()
        window
      "should have no effect": (window)->
        assert.length window.history, 0
        assert.isUndefined window.location.href

  "pushState":
    visit "http://localhost:3003/"
      ready: (err,window)->
        window.history.pushState { is: "start" }, null, "/start"
        window.history.pushState { is: "end" }, null, "/end"
        @callback err, window
      "should add state to history": (window)-> assert.length window.history, 3
      "should change location URL": (window)-> assert.equal window.location.href, "/end"
      "go backwards":
        topic: (window)->
          window.addEventListener "popstate", (evt)=> @callback(null, evt)
          window.history.back()
        "should fire popstate event": (evt)-> assert.instanceOf evt, jsdom.dom.level3.events.Event
        "should include state": (evt)-> assert.equal evt.state.is, "start"
      "go forwards":
        visit "http://localhost:3003/"
          ready: (err, window)->
            window.history.pushState { is: "start" }, null, "/start"
            window.history.pushState { is: "end" }, null, "/end"
            window.history.back()
            window.addEventListener "popstate", (evt)=> @callback(null, evt)
            window.history.forward()
          "should fire popstate event": (evt)-> assert.instanceOf evt, jsdom.dom.level3.events.Event
          "should include state": (evt)-> assert.equal evt.state.is, "end"

  "navigate":
    visit "http://localhost:3003/"
      "should add page to history": (window)-> assert.length window.history, 1
      "should change location URL": (window)-> assert.equal window.location.href, "http://localhost:3003/"
      "should load document": (window)-> assert.match window.document.innerHTML, /Little Red/

}).export(module);
