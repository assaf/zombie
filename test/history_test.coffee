{ assert, brains, Browser } = require("./helpers")
JSDOM = require("jsdom")
URL   = require("url")


describe "History", ->

  file_url = "file://#{__dirname}/data/index.html"


  before (done)->
    brains.get "/history/boo/", (req, res)->
      response = if req.query.redirected then "Redirected" else "Eeek!"
      res.send "<html><title>#{response}</title></html>"

    brains.get "/history/boo", (req, res)->
      res.redirect URL.format(pathname: "/history/boo/", query: req.query)

    brains.get "/history/redirect", (req, res)->
      res.redirect "/history/boo?redirected=true"

    brains.get "/history/redirect_back", (req, res)->
      res.redirect req.headers["referer"]

    brains.get "/history/referer", (req, res)->
      res.send "<html><title>#{req.headers["referer"]}</title></html>"

    brains.get "/history/referer2", (req, res)->
      res.send "<html><title>#{req.headers["referer"]}</title></html>"

    brains.get "/history/form_redirect", (req, res)->
      res.redirect "/history/form?qsval=1"

    brains.get "/history/form", (req, res)->
      res.send """<html><body><form method="post" action="/history/submit?qsval=2"><input type="submit", id="submitbtn"></input></form></body></html>"""

    brains.post "/history/submit", (req, res)->
      res.send "<html><title>#{req.headers["referer"]}</title></html>"

    brains.get "/history/login", (req, res)->
      res.redirect "http://localhost:3003/history/site"
    
    brains.get "/history/site", (req, res)->
      res.send """<html><body><script src="/assets/foo.js"></script></body></html>"""

    brains.get "/assets/foo.js", (req, res)->
      res.send """window.host = "#{req.headers["host"]}"; """

    brains.ready done

  describe "URL without path", ->
    before (done)->
      @browser = new Browser()
      @browser.visit "http://localhost:3003", done

    it "should resolve URL", ->
      @browser.assert.url "http://localhost:3003/"
    it "should load page", ->
      @browser.assert.text "title", "Tap, Tap"


  describe "new window", ->
    before ->
      @browser = new Browser()
      @window = @browser.open()

    it "should start out with one location", ->
      assert.equal @window.history.length, 1
      @browser.assert.url "about:blank"

    describe "go forward", ->
      before ->
        @window.history.forward()

      it "should have no effect", ->
        assert.equal @window.history.length, 1
        @browser.assert.url "about:blank"

    describe "go backwards", ->
      before ->
        @window.history.back()

      it "should have no effect", ->
        assert.equal @window.history.length, 1
        @browser.assert.url "about:blank"


  describe "history", ->

    describe "pushState", ->
      before (done)->
        @browser = new Browser()
        @browser.visit "http://localhost:3003/", =>
          @browser.history.pushState({ is: "start" }, null, "/start")
          @browser.history.pushState({ is: "end" },   null, "/end")
          @window = @browser.window
          @browser.wait(done)

      it "should add state to history", ->
        assert.equal @window.history.length, 3
      it "should change location URL", ->
        @browser.assert.url "http://localhost:3003/end"

      describe "go backwards", ->
        before (done)->
          @window.document.magic = 123
          @window.addEventListener "popstate", (@event)=>
            done()
          @window.history.back()
          @browser.wait()

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
          browser = new Browser()
          browser.visit "http://localhost:3003/", =>
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
        @browser = new Browser()
        @browser.visit "http://localhost:3003/", =>
          @browser.history.pushState { is: "start" },  null, "/start"
          @browser.history.replaceState { is: "end" }, null, "/end"
          @window = @browser.window
          @browser.wait(done)

      it "should not add state to history", ->
        assert.equal @window.history.length, 2
      it "should change location URL", ->
        @browser.assert.url "http://localhost:3003/end"

      describe "go backwards", ->
        before (done)->
          @window.addEventListener "popstate", (evt)=>
            @window.popstate = true
          @window.history.back()
          @browser.wait(done)

        it "should change location URL", ->
          @browser.assert.url "http://localhost:3003/"
        it "should fire popstate event", ->
          assert @window.popstate


    describe "redirect", ->
      before (done)->
        @browser = new Browser()
        @browser.visit "http://localhost:3003/history/redirect", done

      it "should redirect to final destination", ->
        @browser.assert.url "http://localhost:3003/history/boo/?redirected=true"
      it "should pass query parameter", ->
        @browser.assert.text "title", "Redirected"
      it "should not add location in history", ->
        assert.equal @browser.history.length, 1
      it "should indicate last request followed a redirect", ->
        @browser.assert.redirected()

    describe "redirect back", ->
      before (done)->
        @browser = new Browser()
        @browser.visit "http://localhost:3003/history/boo", =>
          @browser.visit "http://localhost:3003/history/redirect_back", done

      it "should redirect to the previous path", ->
        @browser.assert.url "http://localhost:3003/history/boo/"
      it "should pass query parameter", ->
        @browser.assert.text "title", /Eeek!/
      it "should not add location in history", ->
        assert.equal @browser.history.length, 2
      it "should indicate last request followed a redirect", ->
        @browser.assert.redirected()


  describe "location", ->

    describe "open page", ->
      before (done)->
        @browser = new Browser()
        @browser.visit "http://localhost:3003/", done

      it "should add page to history", ->
        assert.equal @browser.history.length, 1
      it "should change location URL", ->
        @browser.assert.url "http://localhost:3003/"
      it "should load document", ->
        @browser.assert.text "html", /Tap, Tap/
      it "should set window location", ->
        @browser.assert.url "http://localhost:3003/"
      it "should set document location", ->
        @browser.assert.url "http://localhost:3003/"

    describe "open from file system", ->
      before (done)->
        @browser = new Browser()
        @browser.visit file_url, done

      it "should add page to history", ->
        assert.equal @browser.history.length, 1
      it "should change location URL", ->
        @browser.assert.url file_url
      it "should load document", ->
        assert ~@browser.html("title").indexOf("Insanely fast, headless full-stack testing using Node.js")
      it "should set window location", ->
        assert.equal @browser.window.location.href, file_url
      it "should set document location", ->
        assert.equal @browser.document.location.href, file_url

    describe "change pathname", ->
      before (done)->
        @browser = new Browser()
        @browser.visit "http://localhost:3003/", =>
          @browser.window.location.pathname = "/history/boo"
          @browser.on "loaded", ->
            done()
          @browser.wait()

      it "should add page to history", ->
        assert.equal @browser.history.length, 2
      it "should change location URL", ->
        @browser.assert.url "http://localhost:3003/history/boo/"
      it "should load document", ->
        @browser.assert.text "html", /Eeek!/

    describe "change relative href", ->
      before (done)->
        @browser = new Browser()
        @browser.visit "http://localhost:3003/", =>
          @browser.window.location.href = "/history/boo"
          @browser.on "loaded", ->
            done()
          @browser.wait()

      it "should add page to history", ->
        assert.equal @browser.history.length, 2
      it "should change location URL", ->
        @browser.assert.url "http://localhost:3003/history/boo/"
      it "should load document", ->
        @browser.assert.text "html", /Eeek!/

    describe "change hash", ->
      before (done)->
        @browser = new Browser()
        @browser.visit "http://localhost:3003/", =>
          @browser.document.innerHTML = "Wolf"
          @browser.window.addEventListener "hashchange", ->
            done()
          @browser.window.location.hash = "boo"
          @browser.wait()

      it "should add page to history", ->
        assert.equal @browser.history.length, 2
      it "should change location URL", ->
        @browser.assert.url "http://localhost:3003/#boo"
      it "should not reload document", ->
        @browser.assert.text "body", /Wolf/

    describe "assign", ->
      before (done)->
        @browser = new Browser()
        @browser.visit "http://localhost:3003/", =>
          @browser.window.location.assign "http://localhost:3003/history/boo"
          @browser.on "loaded", ->
            done()
          @browser.wait()

      it "should add page to history", ->
        assert.equal @browser.history.length, 2
      it "should change location URL", ->
        @browser.assert.url "http://localhost:3003/history/boo/"
      it "should load document", ->
        @browser.assert.text "html", /Eeek!/

    describe "replace", ->
      before (done)->
        @browser = new Browser()
        @browser.visit "http://localhost:3003/", =>
          @browser.window.location.replace "http://localhost:3003/history/boo"
          @browser.on "loaded", ->
            done()
          @browser.wait()

      it "should not add page to history", ->
        assert.equal @browser.history.length, 1
      it "should change location URL", ->
        @browser.assert.url "http://localhost:3003/history/boo/"
      it "should load document", ->
        @browser.assert.text "html", /Eeek!/

    describe "reload", ->
      before (done)->
        @browser = new Browser()
        @browser.visit "http://localhost:3003/", =>
          @browser.window.document.innerHTML = "Wolf"
          @browser.reload()
          @browser.on "loaded", ->
            done()
          @browser.wait()

      it "should not add page to history", ->
        assert.equal @browser.history.length, 1
      it "should not change location URL", ->
        @browser.assert.url "http://localhost:3003/"
      it "should reload document", ->
        @browser.assert.text "html", /Tap, Tap/

    describe "components", ->
      before (done)->
        browser = new Browser()
        browser.visit "http://localhost:3003/", =>
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
        @browser = new Browser()
        @browser.visit "http://localhost:3003/", =>
          @browser.window.location = "http://localhost:3003/history/boo"
          @browser.on "loaded", ->
            done()
          @browser.wait()

      it "should add page to history", ->
        assert.equal @browser.history.length, 2
      it "should change location URL", ->
        @browser.assert.url "http://localhost:3003/history/boo/"
      it "should load document", ->
        @browser.assert.text "html", /Eeek!/

    describe "set document.location", ->
      before (done)->
        @browser = new Browser()
        @browser.visit "http://localhost:3003/", =>
          @browser.window.document.location = "http://localhost:3003/history/boo"
          @browser.on "loaded", ->
            done()
          @browser.wait()

      it "should add page to history", ->
        assert.equal @browser.history.length, 2
      it "should change location URL", ->
        @browser.assert.url "http://localhost:3003/history/boo/"
      it "should load document", ->
        @browser.assert.text "html", /Eeek!/


  describe "referer not set", ->

    describe "first page", ->
      before (done)->
        @browser = new Browser()
        @browser.visit "http://localhost:3003/history/referer", done

      it "should be empty", ->
        @browser.assert.text "title", "undefined"

      describe "second page", ->
        before (done)->
          @browser.visit "http://localhost:3003/history/referer2", done

        it "should point to first page", ->
          @browser.assert.text "title", "http://localhost:3003/history/referer"

  describe "referer set", ->

    describe "first page", ->
      before (done)->
        @browser = new Browser()
        @browser.visit "http://localhost:3003/history/referer", referer: "http://braindepot", done

      it "should be set from browser", ->
        @browser.assert.text "title", "http://braindepot"

      describe "second page", ->
        before (done)->
          @browser.visit "http://localhost:3003/history/referer2", done

        it "should point to first page", ->
          @browser.assert.text "title", "http://localhost:3003/history/referer"

  describe "URL with hash", ->
    before (done)->
      @browser = new Browser()
      @browser.visit "http://localhost:3003#with-hash", done

    it "should load page", ->
      @browser.assert.text "title", "Tap, Tap"
    it "should set location to hash", ->
      assert.equal @browser.location.hash, "#with-hash"

  describe "HTML form", ->
    before (done)->
      @browser = new Browser()
      @browser.visit "http://localhost:3003/history/form?qsval=1", done

    describe "submit", ->
      before (done)->
        @browser.pressButton '#submitbtn', done

      it "should point to first page", ->
        @browser.assert.text "title", "http://localhost:3003/history/form?qsval=1"
        assert.equal ('' + @browser.location), "http://localhost:3003/history/submit?qsval=2"

  describe "HTML form after redirect", ->
    before (done)->
      @browser = new Browser()
      @browser.visit "http://localhost:3003/history/form_redirect", done

    describe "submit", ->
      before (done)->
        @browser.pressButton '#submitbtn', done

      it "should point to first page", ->
        @browser.assert.text "title", "http://localhost:3003/history/form?qsval=1"
        assert.equal @browser.location.href, "http://localhost:3003/history/submit?qsval=2"
  
  describe "Linked Asset after redirect", ->
    before (done)->
      @browser = new Browser()
      # We use host.localhost vs localhost as different "hosts"
      @browser.visit "http://host.localhost:3003/history/login", done
    it 'should load the asset relative to the destination url', ->
      assert.equal @browser.evaluate('window.host'), "localhost:3003"

  describe "replaceState", ->
    before (done)->
      @browser = new Browser()
      @browser.visit "http://localhost:3003/", =>
        @browser.history.pushState { is: "start" },  null, "/start"
        @browser.history.replaceState { is: "end" }, null, "/end"
        @window = @browser.window
        @browser.wait(done)

    describe "second page", ->
      before (done)->
        @browser.visit '/history/referer', done

      it "should point to the pushed state", ->
        @browser.assert.text "title", "http://localhost:3003/end"

