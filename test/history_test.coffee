{ assert, brains, Browser } = require("./helpers")
JSDOM = require("jsdom")
URL   = require("url")


describe "History", ->

  browser = null
  before (done)->
    browser = Browser.create()
    brains.ready(done)


  before ->
    brains.get "/history/boo/", (req, res)->
      response = if req.query.redirected then "Redirected" else "Eeek!"
      res.send "<html><title>#{response}</title></html>"

    brains.get "/history/boo", (req, res)->
      res.redirect URL.format(pathname: "/history/boo/", query: req.query)

    brains.get "/history/redirect", (req, res)->
      res.redirect "/history/boo?redirected=true"

    brains.get "/history/redirect_back", (req, res)->
      res.redirect req.headers.referer

    brains.get "/history/referer", (req, res)->
      res.send "<html><title>#{req.headers["referer"]}</title></html>"

    brains.get "/history/referer2", (req, res)->
      res.send "<html><title>#{req.headers["referer"]}</title></html>"


  describe "URL without path", ->
    before (done)->
      browser.visit("/", done)

    it "should resolve URL", ->
      browser.assert.url "http://localhost:3003/"
    it "should load page", ->
      browser.assert.text "title", "Tap, Tap"


  describe "new window", ->
    before ->
      browser.close()
      @window = browser.open()

    it "should start out with one location", ->
      assert.equal @window.history.length, 1
      browser.assert.url "about:blank"

    describe "go forward", ->
      before ->
        @window.history.forward()

      it "should have no effect", ->
        assert.equal @window.history.length, 1
        browser.assert.url "about:blank"

    describe "go backwards", ->
      before ->
        @window.history.back()

      it "should have no effect", ->
        assert.equal @window.history.length, 1
        browser.assert.url "about:blank"


  describe "history", ->

    describe "pushState", ->
      before (done)->
        browser.visit "/", ->
          browser.history.pushState({ is: "start" }, null, "/start")
          browser.history.pushState({ is: "end" },   null, "/end")
          browser.wait(done)
      before ->
        @window = browser.window

      it "should add state to history", ->
        assert.equal @window.history.length, 3
      it "should change location URL", ->
        browser.assert.url "http://localhost:3003/end"

      describe "go backwards", ->
        before (done)->
          @window.document.magic = 123
          @window.addEventListener "popstate", (@event)=>
            done()
          @window.history.back()
          browser.wait()

        it "should fire popstate event", ->
          assert @event instanceof JSDOM.dom.level3.events.Event
        it "should include state", ->
          assert.equal @event.state.is, "start"
        it "should not reload page from same host", ->
          # Get access to the *current* document
          document = @event.target.window.browser.document
          assert.equal document.magic, 123

      describe "go forwards", ->
        before (done)->
          browser.visit "/", =>
            browser.history.pushState { is: "start" }, null, "/start"
            browser.history.pushState { is: "end" },   null, "/end"
            browser.back()
            browser.window.addEventListener "popstate", (@event)=>
              done()
            browser.history.forward()

        it "should fire popstate event", ->
          assert @event instanceof JSDOM.dom.level3.events.Event
        it "should include state", ->
          assert.equal @event.state.is, "end"


    describe "replaceState", ->
      before (done)->
        browser.visit "/", ->
          browser.history.pushState { is: "start" },  null, "/start"
          browser.history.replaceState { is: "end" }, null, "/end"
          browser.wait(done)
      before ->
        @window = browser.window

      it "should not add state to history", ->
        assert.equal @window.history.length, 2
      it "should change location URL", ->
        browser.assert.url "http://localhost:3003/end"

      describe "go backwards", ->
        before (done)->
          @window.addEventListener "popstate", (evt)=>
            @window.popstate = true
          @window.history.back()
          browser.wait(done)

        it "should change location URL", ->
          browser.assert.url "http://localhost:3003/"
        it "should fire popstate event", ->
          assert @window.popstate


    describe "redirect", ->
      before (done)->
        browser.visit("/history/redirect", done)

      it "should redirect to final destination", ->
        browser.assert.url "http://localhost:3003/history/boo/?redirected=true"
      it "should pass query parameter", ->
        browser.assert.text "title", "Redirected"
      it "should not add location in history", ->
        assert.equal browser.history.length, 1
      it "should indicate last request followed a redirect", ->
        browser.assert.redirected()

    describe "redirect back", ->
      before (done)->
        browser.visit "/history/boo", ->
          browser.location = "/history/redirect_back"
          browser.wait(done)

      it "should redirect to the previous path", ->
        browser.assert.url "http://localhost:3003/history/boo/"
      it "should pass query parameter", ->
        browser.assert.text "title", /Eeek!/
      it "should not add location in history", ->
        assert.equal browser.history.length, 2
      it "should indicate last request followed a redirect", ->
        browser.assert.redirected()


  describe "location", ->

    describe "open page", ->
      before (done)->
        browser.visit("/history/boo", done)

      it "should add page to history", ->
        assert.equal browser.history.length, 1
      it "should change location URL", ->
        browser.assert.url "http://localhost:3003/history/boo/"
      it "should load document", ->
        browser.assert.text "title", /Eeek!/
      it "should set window location", ->
        browser.assert.url "http://localhost:3003/history/boo/"
      it "should set document location", ->
        browser.assert.url "http://localhost:3003/history/boo/"

    describe "open from file system", ->
      fileURL = encodeURI("file://#{__dirname}/data/index.html")

      before (done)->
        browser.visit(fileURL, done)

      it "should add page to history", ->
        assert.equal browser.history.length, 1
      it "should change location URL", ->
        browser.assert.url fileURL
      it "should load document", ->
        assert ~browser.html("title").indexOf("Insanely fast, headless full-stack testing using Node.js")
      it "should set window location", ->
        assert.equal browser.window.location.href, fileURL
      it "should set document location", ->
        assert.equal browser.document.location.href, fileURL

    describe "change pathname", ->
      before (done)->
        browser.visit "/", ->
          browser.window.location.pathname = "/history/boo"
          browser.once "loaded", ->
            done()
          browser.wait()

      it "should add page to history", ->
        assert.equal browser.history.length, 2
      it "should change location URL", ->
        browser.assert.url "http://localhost:3003/history/boo/"
      it "should load document", ->
        browser.assert.text "title", /Eeek!/

    describe "change relative href", ->
      before (done)->
        browser.visit "/", ->
          browser.window.location.href = "/history/boo"
          browser.once "loaded", ->
            done()
          browser.wait()

      it "should add page to history", ->
        assert.equal browser.history.length, 2
      it "should change location URL", ->
        browser.assert.url "http://localhost:3003/history/boo/"
      it "should load document", ->
        browser.assert.text "title", /Eeek!/

    describe "change hash", ->
      before (done)->
        browser.visit "/", ->
          browser.document.innerHTML = "<html><body>Wolf</body></html>"
          browser.window.addEventListener "hashchange", ->
            done()
          browser.window.location.hash = "boo"
          browser.wait()

      it "should add page to history", ->
        assert.equal browser.history.length, 2
      it "should change location URL", ->
        browser.assert.url "http://localhost:3003/#boo"
      it "should not reload document", ->
        browser.assert.text "body", /Wolf/

    describe "assign", ->
      before (done)->
        browser.visit "/", ->
          browser.window.location.assign "http://localhost:3003/history/boo"
          browser.once "loaded", ->
            done()
          browser.wait()

      it "should add page to history", ->
        assert.equal browser.history.length, 2
      it "should change location URL", ->
        browser.assert.url "http://localhost:3003/history/boo/"
      it "should load document", ->
        browser.assert.text "title", /Eeek!/

    describe "replace", ->
      before (done)->
        browser.visit "/", ->
          browser.window.location.replace "http://localhost:3003/history/boo"
          browser.once "loaded", ->
            done()
          browser.wait()

      it "should not add page to history", ->
        assert.equal browser.history.length, 1
      it "should change location URL", ->
        browser.assert.url "http://localhost:3003/history/boo/"
      it "should load document", ->
        browser.assert.text "title", /Eeek!/

    describe "reload", ->
      before (done)->
        browser.visit "/", ->
          browser.window.document.innerHTML = "Wolf"
          browser.reload()
          browser.once "loaded", ->
            done()
          browser.wait()

      it "should not add page to history", ->
        assert.equal browser.history.length, 1
      it "should not change location URL", ->
        browser.assert.url "http://localhost:3003/"
      it "should reload document", ->
        browser.assert.text "title", /Tap, Tap/

    describe "components", ->
      before (done)->
        browser.visit "/", =>
          @location = browser.location
          done()

      it "should include protocol", ->
        assert.equal @location.protocol, "http:"
      it "should include hostname", ->
        assert.equal @location.hostname, "localhost"
      it "should include port", ->
        assert.equal @location.port, 3003
      it "should include hostname and port", ->
        assert.equal @location.host, "localhost:3003"
      it "should include pathname", ->
        assert.equal @location.pathname, "/"
      it "should include search", ->
        assert.equal @location.search, ""
      it "should include hash", ->
        assert.equal @location.hash, ""

    describe "set window.location", ->
      before (done)->
        browser.visit "/", ->
          browser.window.location = "http://localhost:3003/history/boo"
          browser.once "loaded", ->
            done()
          browser.wait()

      it "should add page to history", ->
        assert.equal browser.history.length, 2
      it "should change location URL", ->
        browser.assert.url "http://localhost:3003/history/boo/"
      it "should load document", ->
        browser.assert.text "title", /Eeek!/

    describe "set document.location", ->
      before (done)->
        browser.visit "/", ->
          browser.window.document.location = "http://localhost:3003/history/boo"
          browser.once "loaded", ->
            done()
          browser.wait()

      it "should add page to history", ->
        assert.equal browser.history.length, 2
      it "should change location URL", ->
        browser.assert.url "http://localhost:3003/history/boo/"
      it "should load document", ->
        browser.assert.text "title", /Eeek!/


  describe "referer not set", ->
    before (done)->
      browser.visit("/history/referer", done)

    it "should be empty", ->
      browser.assert.text "title", ""

  describe "referer set", ->
    before (done)->
      browser.visit("/history/referer", referer: "http://braindepot", done)

    it "should be set from browser", ->
      browser.assert.text "title", "http://braindepot"


  describe "URL with hash", ->
    before (done)->
      browser.visit("/#with-hash", done)

    it "should load page", ->
      browser.assert.text "title", "Tap, Tap"
    it "should set location to hash", ->
      assert.equal browser.location.hash, "#with-hash"


  after ->
    browser.destroy()
