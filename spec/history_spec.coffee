{ vows: vows, assert: assert, brains: brains, Browser: Browser, Zombie: Zombie } = require("./helpers")
JSDOM = require("jsdom")


brains.get "/history/boo", (req, res)->
  response = if req.query.redirected then "Redirected" else "Eeek!"
  res.send "<html><title>#{response}</title></html>"

brains.get "/history/redirect", (req, res)->
  res.redirect "/history/boo?redirected=true"

brains.get "/history/redirect_back", (req, res)->
  res.redirect req.headers['referer']

file_url = "file://#{__dirname}/data/index.html"


vows.describe("History").addBatch(

  "new window":
    topic: ->
      new Browser().window
    "should start out empty": (window)->
      assert.lengthOf window.history, 0
    "should start out with no location": (window)->
      assert.isUndefined window.location.href
    "go forward":
      topic: (window)->
        window.history.forward()
        window
      "should have no effect": (window)->
        assert.lengthOf window.history, 0
        assert.isUndefined window.location.href
    "go backwards":
      topic: (window)->
        window.history.back()
        window
      "should have no effect": (window)->
        assert.lengthOf window.history, 0
        assert.isUndefined window.location.href

  "history":
    "pushState":
      Zombie.wants "http://localhost:3003/"
        topic: (browser)->
          browser.window.history.pushState { is: "start" }, null, "/start"
          browser.window.history.pushState { is: "end" },   null, "/end"
          @callback null, browser.window
        "should add state to history": (window)->
          assert.lengthOf window.history, 3
        "should change location URL": (window)->
          assert.equal window.location.href, "http://localhost:3003/end"

        "go backwards":
          topic: (window)->
            window.addEventListener "popstate", (evt)=> @callback(null, evt)
            window.history.back()
            return
          "should fire popstate event": (evt)->
            assert.instanceOf evt, JSDOM.dom.level3.events.Event
          "should include state": (evt)->
            assert.equal evt.state.is, "start"

        "go forwards":
          Zombie.wants "http://localhost:3003/"
            topic: (browser)->
              browser.window.history.pushState { is: "start" }, null, "/start"
              browser.window.history.pushState { is: "end" },   null, "/end"
              browser.window.history.back()
              browser.window.addEventListener "popstate", (evt)=>
                @callback(null, evt)
              browser.window.history.forward()
              return
            "should fire popstate event": (evt)->
              assert.instanceOf evt, JSDOM.dom.level3.events.Event
            "should include state": (evt)->
              assert.equal evt.state.is, "end"

    "replaceState":
      Zombie.wants "http://localhost:3003/"
        topic: (browser)->
          browser.window.history.pushState { is: "start" },  null, "/start"
          browser.window.history.replaceState { is: "end" }, null, "/end"
          @callback null, browser.window
        "should not add state to history": (window)->
          assert.lengthOf window.history, 2
        "should change location URL": (window)->
          assert.equal window.location.href, "http://localhost:3003/end"

        "go backwards":
          topic: (browser)->
            browser.window.addEventListener "popstate", (evt)=>
              browser.window.popstate = true
            browser.window.history.back()
            @callback null, browser.window
          "should change location URL": (window)->
            assert.equal window.location.href, "http://localhost:3003/"
          "should not fire popstate event": (window)->
            assert.isUndefined window.popstate

    "redirect":
      Zombie.wants "http://localhost:3003/history/redirect"
        "should redirect to final destination": (browser)->
          assert.equal browser.location, "http://localhost:3003/history/boo?redirected=true"
        "should pass query parameter": (browser)->
          assert.equal browser.text("title"), "Redirected"
        "should not add location in history": (browser)->
          assert.lengthOf browser.window.history, 1
        "should indicate last request followed a redirect": (browser)->
          assert.ok browser.redirected

    "redirect back":
      Zombie.wants "http://localhost:3003/history/boo"
        topic: (browser)->
          browser.visit "http://localhost:3003/history/redirect_back"
          browser.window.document.addEventListener "DOMContentLoaded", =>
            @callback null, browser
          return
        "should redirect to the previous path": (browser)->
          assert.equal browser.location.href, "http://localhost:3003/history/boo"
        "should pass query parameter": (browser)->
          assert.match browser.text("title"), /Eeek!/
        "should not add location in history": (browser)->
          assert.lengthOf browser.window.history, 2
        "should indicate last request followed a redirect": (browser)->
          assert.ok browser.redirected


  "location":
    "open page":
      Zombie.wants "http://localhost:3003/"
        "should add page to history": (browser)->
          assert.lengthOf browser.window.history, 1
        "should change location URL": (browser)->
          assert.equal browser.location, "http://localhost:3003/"
        "should load document": (browser)->
          assert.match browser.html(), /Tap, Tap/
        "should set window location": (browser)->
          assert.equal browser.window.location.href, "http://localhost:3003/"
        "should set document location": (browser)->
          assert.equal browser.document.location.href, "http://localhost:3003/"

    "open from file system":
      Zombie.wants `file_url`
        "should add page to history": (browser)->
          assert.lengthOf browser.window.history, 1
        "should change location URL": (browser)->
          assert.equal browser.location, file_url
        "should load document": (browser)->
          assert.include browser.html("title"), "Insanely fast, headless full-stack testing using Node.js"
        "should set window location": (browser)->
          assert.equal browser.window.location.href, file_url
        "should set document location": (browser)->
          assert.equal browser.document.location.href, file_url

    "change pathname":
      Zombie.wants "http://localhost:3003/"
        topic: (browser)->
          browser.window.location.pathname = "/history/boo"
          browser.window.document.addEventListener "DOMContentLoaded", =>
            @callback null, browser
          return
        "should add page to history": (browser)->
          assert.lengthOf browser.window.history, 2
        "should change location URL": (browser)->
          assert.equal browser.location, "http://localhost:3003/history/boo"
        "should load document": (browser)->
          assert.match browser.html(), /Eeek!/

    "change relative href":
      Zombie.wants "http://localhost:3003/"
        topic: (browser)->
          browser.window.location.href = "/history/boo"
          browser.window.document.addEventListener "DOMContentLoaded", =>
            @callback null, browser
          return
        "should add page to history": (browser)->
          assert.lengthOf browser.window.history, 2
        "should change location URL": (browser)->
          assert.equal browser.location, "http://localhost:3003/history/boo"
        "should load document": (browser)->
          assert.match browser.html(), /Eeek!/

    "change hash":
      Zombie.wants "http://localhost:3003/"
        topic: (browser)->
          browser.document.innerHTML = "Wolf"
          browser.window.addEventListener "hashchange", =>
            @callback null, browser
          browser.window.location.hash = "boo"
          return
        "should add page to history": (browser)->
          assert.lengthOf browser.window.history, 2
        "should change location URL": (browser)->
          assert.equal browser.location, "http://localhost:3003/#boo"
        "should not reload document": (browser)->
          assert.match browser.document.innerHTML, /Wolf/

    "assign":
      Zombie.wants "http://localhost:3003/"
        topic: (browser)->
          @window = browser.window
          browser.window.location.assign "http://localhost:3003/history/boo"
          browser.document.addEventListener "DOMContentLoaded", =>
            @callback null, browser
          return
        "should add page to history": (browser)->
          assert.lengthOf browser.window.history, 2
        "should change location URL": (browser)->
          assert.equal browser.location, "http://localhost:3003/history/boo"
        "should load document": (browser)->
          assert.match browser.html(), /Eeek!/
        "should load document in new window": (browser)->
          assert.ok browser.window != @window

    "replace":
      Zombie.wants "http://localhost:3003/"
        topic: (browser)->
          @window = browser.window
          browser.window.location.replace "http://localhost:3003/history/boo"
          browser.window.document.addEventListener "DOMContentLoaded", =>
            @callback null, browser
          return
        "should not add page to history": (browser)->
          assert.lengthOf browser.window.history, 1
        "should change location URL": (browser)->
          assert.equal browser.location, "http://localhost:3003/history/boo"
        "should load document": (browser)->
          assert.match browser.html(), /Eeek!/
        "should load document in new window": (browser)->
          assert.ok browser.window != @window

    "reload":
      Zombie.wants "http://localhost:3003/"
        topic: (browser)->
          @window = browser.window
          browser.window.document.innerHTML = "Wolf"
          browser.window.location.reload()
          browser.window.document.addEventListener "DOMContentLoaded", =>
            @callback null, browser
          return
        "should not add page to history": (browser)->
          assert.lengthOf browser.window.history, 1
        "should not change location URL": (browser)->
          assert.equal browser.location, "http://localhost:3003/"
        "should reload document": (browser)->
          assert.match browser.html(), /Tap, Tap/
        "should reload document in new window": (browser)->
          assert.ok browser.window != @window

    "components":
      Zombie.wants "http://localhost:3003/"
        topic: (browser)-> browser.location
        "should include protocol": (location)->
          assert.equal location.protocol, "http:"
        "should include hostname": (location)->
          assert.equal location.hostname, "localhost"
        "should include port": (location)->
          assert.equal location.port, 3003
        "should include hostname and port": (location)->
          assert.equal location.host, "localhost:3003"
        "should include pathname": (location)->
          assert.equal location.pathname, "/"
        "should include search": (location)->
          assert.equal location.search, ""
        "should include hash": (location)->
          assert.equal location.hash, ""

    "set window.location":
      Zombie.wants "http://localhost:3003/"
        topic: (browser)->
          browser.window.location = "http://localhost:3003/history/boo"
          browser.window.document.addEventListener "DOMContentLoaded", =>
            @callback null, browser
          return
        "should add page to history": (browser)->
          assert.lengthOf browser.window.history, 2
        "should change location URL": (browser)->
          assert.equal browser.location, "http://localhost:3003/history/boo"
        "should load document": (browser)->
          assert.match browser.html(), /Eeek!/

    "set document.location":
      Zombie.wants "http://localhost:3003/"
        topic: (browser)->
          browser.window.document.location = "http://localhost:3003/history/boo"
          browser.window.document.addEventListener "DOMContentLoaded", =>
            @callback null, browser
          return
        "should add page to history": (browser)->
          assert.lengthOf browser.window.history, 2
        "should change location URL": (browser)->
          assert.equal browser.location, "http://localhost:3003/history/boo"
        "should load document": (browser)->
          assert.match browser.html(), /Eeek!/

).export(module)
