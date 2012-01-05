{ Vows, assert, brains, Browser } = require("./helpers")
JSDOM = require("jsdom")


brains.get "/history/boo", (req, res)->
  response = if req.query.redirected then "Redirected" else "Eeek!"
  res.send "<html><title>#{response}</title></html>"

brains.get "/history/redirect", (req, res)->
  res.redirect "/history/boo?redirected=true"

brains.get "/history/redirect_back", (req, res)->
  res.redirect req.headers["referer"]

brains.get "/history/referer", (req, res)->
  res.send "<html><title>#{req.headers["referer"]}</title></html>"

file_url = "file://#{__dirname}/data/index.html"


Vows.describe("History").addBatch

  "URL without path":
    Browser.wants "http://localhost:3003"
      "should resolve URL": (browser)->
        assert.equal browser.location.href, "http://localhost:3003/"
      "should load page": (browser)->
        assert.equal browser.text("title"), "Tap, Tap"

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
      Browser.wants "http://localhost:3003/"
        topic: (browser)->
          browser.history.pushState { is: "start" }, null, "/start"
          browser.history.pushState { is: "end" },   null, "/end"
          @callback null, browser.window
        "should add state to history": (window)->
          assert.lengthOf window.history, 3
        "should change location URL": (window)->
          assert.equal window.location.href, "http://localhost:3003/end"

        "go backwards":
          topic: (window)->
            window.document.magic = 123
            window.addEventListener "popstate", (evt)=>
              @callback(null, evt)
            window.history.back()
            return
          "should fire popstate event": (evt)->
            assert.instanceOf evt, JSDOM.dom.level3.events.Event
          "should include state": (evt)->
            assert.equal evt.state.is, "start"
          "should not reload page from same host": (evt)->
            # Get access to the *current* document
            document = evt.target.window.browser.document
            assert.equal document.magic, 123

        "go forwards":
          Browser.wants "http://localhost:3003/"
            topic: (browser)->
              browser.history.pushState { is: "start" }, null, "/start"
              browser.history.pushState { is: "end" },   null, "/end"
              browser.back()
              browser.window.addEventListener "popstate", (evt)=>
                @callback(null, evt)
              browser.history.forward()
              return
            "should fire popstate event": (evt)->
              assert.instanceOf evt, JSDOM.dom.level3.events.Event
            "should include state": (evt)->
              assert.equal evt.state.is, "end"

    "replaceState":
      Browser.wants "http://localhost:3003/"
        topic: (browser)->
          browser.history.pushState { is: "start" },  null, "/start"
          browser.history.replaceState { is: "end" }, null, "/end"
          @callback null, browser.window
        "should not add state to history": (window)->
          assert.lengthOf window.history, 2
        "should change location URL": (window)->
          assert.equal window.location.href, "http://localhost:3003/end"

        "go backwards":
          topic: (window)->
            window.addEventListener "popstate", (evt)=>
              window.popstate = true
            window.history.back()
            @callback null, window
          "should change location URL": (window)->
            assert.equal window.location.href, "http://localhost:3003/"
          "should not fire popstate event": (window)->
            assert.isUndefined window.popstate

    "redirect":
      Browser.wants "http://localhost:3003/history/redirect"
        "should redirect to final destination": (browser)->
          assert.equal browser.location, "http://localhost:3003/history/boo?redirected=true"
        "should pass query parameter": (browser)->
          assert.equal browser.text("title"), "Redirected"
        "should not add location in history": (browser)->
          assert.lengthOf browser.history, 1
        "should indicate last request followed a redirect": (browser)->
          assert.ok browser.redirected

    "redirect back":
      Browser.wants "http://localhost:3003/history/boo"
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
          assert.lengthOf browser.history, 2
        "should indicate last request followed a redirect": (browser)->
          assert.ok browser.redirected


  "location":
    "open page":
      Browser.wants "http://localhost:3003/"
        "should add page to history": (browser)->
          assert.lengthOf browser.history, 1
        "should change location URL": (browser)->
          assert.equal browser.location, "http://localhost:3003/"
        "should load document": (browser)->
          assert.match browser.html(), /Tap, Tap/
        "should set window location": (browser)->
          assert.equal browser.window.location.href, "http://localhost:3003/"
        "should set document location": (browser)->
          assert.equal browser.document.location.href, "http://localhost:3003/"

    "open from file system":
      Browser.wants `file_url`
        "should add page to history": (browser)->
          assert.lengthOf browser.history, 1
        "should change location URL": (browser)->
          assert.equal browser.location, file_url
        "should load document": (browser)->
          assert.include browser.html("title"), "Insanely fast, headless full-stack testing using Node.js"
        "should set window location": (browser)->
          assert.equal browser.window.location.href, file_url
        "should set document location": (browser)->
          assert.equal browser.document.location.href, file_url

    "change pathname":
      Browser.wants "http://localhost:3003/"
        topic: (browser)->
          browser.window.location.pathname = "/history/boo"
          browser.window.document.addEventListener "DOMContentLoaded", =>
            @callback null, browser
          return
        "should add page to history": (browser)->
          assert.lengthOf browser.history, 2
        "should change location URL": (browser)->
          assert.equal browser.location, "http://localhost:3003/history/boo"
        "should load document": (browser)->
          assert.match browser.html(), /Eeek!/

    "change relative href":
      Browser.wants "http://localhost:3003/"
        topic: (browser)->
          browser.window.location.href = "/history/boo"
          browser.window.document.addEventListener "DOMContentLoaded", =>
            @callback null, browser
          return
        "should add page to history": (browser)->
          assert.lengthOf browser.history, 2
        "should change location URL": (browser)->
          assert.equal browser.location, "http://localhost:3003/history/boo"
        "should load document": (browser)->
          assert.match browser.html(), /Eeek!/

    "change hash":
      Browser.wants "http://localhost:3003/"
        topic: (browser)->
          browser.document.innerHTML = "Wolf"
          browser.window.addEventListener "hashchange", =>
            @callback null, browser
          browser.window.location.hash = "boo"
          return
        "should add page to history": (browser)->
          assert.lengthOf browser.history, 2
        "should change location URL": (browser)->
          assert.equal browser.location, "http://localhost:3003/#boo"
        "should not reload document": (browser)->
          assert.match browser.document.innerHTML, /Wolf/

    "assign":
      Browser.wants "http://localhost:3003/"
        topic: (browser)->
          @window = browser.window
          browser.window.location.assign "http://localhost:3003/history/boo"
          browser.document.addEventListener "DOMContentLoaded", =>
            @callback null, browser
          return
        "should add page to history": (browser)->
          assert.lengthOf browser.history, 2
        "should change location URL": (browser)->
          assert.equal browser.location, "http://localhost:3003/history/boo"
        "should load document": (browser)->
          assert.match browser.html(), /Eeek!/
        "should load document in new window": (browser)->
          assert.ok browser.window != @window

    "replace":
      Browser.wants "http://localhost:3003/"
        topic: (browser)->
          @window = browser.window
          browser.window.location.replace "http://localhost:3003/history/boo"
          browser.window.document.addEventListener "DOMContentLoaded", =>
            @callback null, browser
          return
        "should not add page to history": (browser)->
          assert.lengthOf browser.history, 1
        "should change location URL": (browser)->
          assert.equal browser.location, "http://localhost:3003/history/boo"
        "should load document": (browser)->
          assert.match browser.html(), /Eeek!/
        "should load document in new window": (browser)->
          assert.ok browser.window != @window

    "reload":
      Browser.wants "http://localhost:3003/"
        topic: (browser)->
          @window = browser.window
          browser.window.document.innerHTML = "Wolf"
          browser.reload()
          browser.window.document.addEventListener "DOMContentLoaded", =>
            @callback null, browser
          return
        "should not add page to history": (browser)->
          assert.lengthOf browser.history, 1
        "should not change location URL": (browser)->
          assert.equal browser.location, "http://localhost:3003/"
        "should reload document": (browser)->
          assert.match browser.html(), /Tap, Tap/
        "should reload document in new window": (browser)->
          assert.ok browser.window != @window

    "components":
      Browser.wants "http://localhost:3003/"
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
      Browser.wants "http://localhost:3003/"
        topic: (browser)->
          browser.window.location = "http://localhost:3003/history/boo"
          browser.window.document.addEventListener "DOMContentLoaded", =>
            @callback null, browser
          return
        "should add page to history": (browser)->
          assert.lengthOf browser.history, 2
        "should change location URL": (browser)->
          assert.equal browser.location, "http://localhost:3003/history/boo"
        "should load document": (browser)->
          assert.match browser.html(), /Eeek!/

    "set document.location":
      Browser.wants "http://localhost:3003/"
        topic: (browser)->
          browser.window.document.location = "http://localhost:3003/history/boo"
          browser.window.document.addEventListener "DOMContentLoaded", =>
            @callback null, browser
          return
        "should add page to history": (browser)->
          assert.lengthOf browser.history, 2
        "should change location URL": (browser)->
          assert.equal browser.location, "http://localhost:3003/history/boo"
        "should load document": (browser)->
          assert.match browser.html(), /Eeek!/


  "referer not set":
    "first page":
      topic: (browser)->
        browser = new Browser()
        browser.wants "http://localhost:3003/history/referer", @callback
      "should be empty": (browser)->
        assert.equal browser.text("title"), "undefined"

      "second page":
        topic: (browser)->
          browser.visit "http://localhost:3003/history/referer", @callback
        "should point to first page": (browser)->
          assert.equal browser.text("title"), "http://localhost:3003/history/referer"

  "referer set":
    "first page":
      topic: (browser)->
        browser = new Browser()
        browser.wants "http://localhost:3003/history/referer", referer: "http://braindepot", @callback
      "should be empty": (browser)->
        assert.equal browser.text("title"), "http://braindepot"

      "second page":
        topic: (browser)->
          browser.visit "http://localhost:3003/history/referer", @callback
        "should point to first page": (browser)->
          assert.equal browser.text("title"), "http://localhost:3003/history/referer"


.export(module)
