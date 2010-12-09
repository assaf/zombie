require.paths.push(__dirname + "/../lib", __dirname)
fs = require("fs")
vows = require("vows", "assert")
assert = require("assert")
jsdom = require("jsdom")
{ browser: browser } = require("zombie")
{ server: server, visit: visit } = require("helpers")


server.get "/boo", (req, res)->
  res.send "<html><title>Eeek!</title></html>"

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

  "history":
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
    "replaceState":
      visit "http://localhost:3003/"
        ready: (err,window)->
          window.history.pushState { is: "start" }, null, "/start"
          window.history.replaceState { is: "end" }, null, "/end"
          @callback err, window
        "should not add state to history": (window)-> assert.length window.history, 2
        "should change location URL": (window)-> assert.equal window.location.href, "/end"
        "go backwards":
          topic: (window)->
            window.addEventListener "popstate", (evt)=> window.popstate = true
            window.history.back()
            @callback null, window
          "should change location URL": (window)-> assert.equal window.location.href, "http://localhost:3003/"
          "should not fire popstate event": (window)-> assert.isUndefined window.popstate

  "location":
    "open page":
      visit "http://localhost:3003/"
        "should add page to history": (window)-> assert.length window.history, 1
        "should change location URL": (window)-> assert.equal window.location.href, "http://localhost:3003/"
        "should load document": (window)-> assert.match window.document.innerHTML, /Little Red/
    "change location":
      visit "http://localhost:3003/"
        ready: (err, window)->
          window.location = "http://localhost:3003/boo"
          window.document.addEventListener "DOMContentLoaded", => @callback err, window
        "should add page to history": (window)-> assert.length window.history, 2
        "should change location URL": (window)-> assert.equal window.location.href, "http://localhost:3003/boo"
        "should load document": (window)-> assert.match window.document.innerHTML, /Eeek!/
    "change pathname":
      visit "http://localhost:3003/"
        ready: (err, window)->
          window.location.pathname = "/boo"
          window.document.addEventListener "DOMContentLoaded", => @callback err, window
        "should add page to history": (window)-> assert.length window.history, 2
        "should change location URL": (window)-> assert.equal window.location.href, "http://localhost:3003/boo"
        "should load document": (window)-> assert.match window.document.innerHTML, /Eeek!/
    "change hash":
      visit "http://localhost:3003/"
        ready: (err, window)->
          window.document.innerHTML = "Wolf"
          window.addEventListener "hashchange", => @callback err, window
          window.location.hash = "boo"
        "should add page to history": (window)-> assert.length window.history, 2
        "should change location URL": (window)-> assert.equal window.location.href, "http://localhost:3003/#boo"
        "should not reload document": (window)-> assert.match window.document.innerHTML, /Wolf/
    "assign":
      visit "http://localhost:3003/"
        ready: (err, window)->
          window.location.assign "http://localhost:3003/boo"
          window.document.addEventListener "DOMContentLoaded", => @callback err, window
        "should add page to history": (window)-> assert.length window.history, 2
        "should change location URL": (window)-> assert.equal window.location.href, "http://localhost:3003/boo"
        "should load document": (window)-> assert.match window.document.innerHTML, /Eeek!/
    "replace":
      visit "http://localhost:3003/"
        ready: (err, window)->
          window.location.replace "http://localhost:3003/boo"
          window.document.addEventListener "DOMContentLoaded", => @callback err, window
        "should not add page to history": (window)-> assert.length window.history, 1
        "should change location URL": (window)-> assert.equal window.location.href, "http://localhost:3003/boo"
        "should load document": (window)-> assert.match window.document.innerHTML, /Eeek!/
    "reload":
      visit "http://localhost:3003/"
        ready: (err, window)->
          window.document.innerHTML = "Wolf"
          window.location.reload()
          window.document.addEventListener "DOMContentLoaded", => @callback err, window
        "should not add page to history": (window)-> assert.length window.history, 1
        "should not change location URL": (window)-> assert.equal window.location.href, "http://localhost:3003/"
        "should reload document": (window)-> assert.match window.document.innerHTML, /Little Red/
}).export(module);
