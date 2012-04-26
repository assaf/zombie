{ assert, brains, Browser } = require("./helpers")
JSDOM = require("jsdom")


describe "History", ->

  file_url = "file://#{__dirname}/data/index.html"


  before (done)->
    brains.get "/history/boo", (req, res)->
      response = if req.query.redirected then "Redirected" else "Eeek!"
      res.send "<html><title>#{response}</title></html>"

    brains.get "/history/redirect", (req, res)->
      res.redirect "/history/boo?redirected=true"

    brains.get "/history/redirect_back", (req, res)->
      res.redirect req.headers["referer"]

    brains.get "/history/referer", (req, res)->
      res.send "<html><title>#{req.headers["referer"]}</title></html>"

    brains.ready done


  describe "URL without path", ->
    browser = new Browser()

    before (done)->
      browser.visit "http://localhost:3003", done

    it "should resolve URL", ->
      assert.equal browser.location.href, "http://localhost:3003/"
    it "should load page", ->
      assert.equal browser.text("title"), "Tap, Tap"


  describe "new window", ->
    window = new Browser().window

    it "should start out empty", ->
      assert.equal window.history.length, 0
    it "should start out with no location", ->
      assert.equal window.location.href, undefined

    describe "go forward", ->
      before ->
        window.history.forward()

      it "should have no effect", ->
        assert.equal window.history.length, 0
        assert.equal window.location.href, undefined

    describe "go backwards", ->
      before ->
        window.history.back()

      it "should have no effect", ->
        assert.equal window.history.length, 0
        assert.equal window.location.href, undefined


  describe "history", ->

    describe "pushState", ->
      window = null

      before (done)->
        browser = new Browser()
        browser.visit "http://localhost:3003/", ->
          browser.history.pushState { is: "start" }, null, "/start"
          browser.history.pushState { is: "end" },   null, "/end"
          window = browser.window
          done()

        it "should add state to history", ->
          assert.equal window.history.length, 3
        it "should change location URL", ->
          assert.equal window.location.href, "http://localhost:3003/end"

        describe "go backwards", ->
          before (done)->
            window.document.magic = 123
            window.addEventListener "popstate", ->
              event = arguments[0]
              done()
            window.history.back()

          it "should fire popstate event", ->
            assert.instanceOf event, JSDOM.dom.level3.events.Event
          it "should include state", ->
            assert.equal event.state.is, "start"
          it "should not reload page from same host", ->
            # Get access to the *current* document
            document = event.target.window.browser.document
            assert.equal document.magic, 123

        describe "go forwards", ->
          event = null

          before (done)->
            browser = new Browser()
            browser.visit "http://localhost:3003/", ->
              browser.history.pushState { is: "start" }, null, "/start"
              browser.history.pushState { is: "end" },   null, "/end"
              browser.back()
              browser.window.addEventListener "popstate", ->
                event = arguments[0]
                done()
              browser.history.forward()

          it "should fire popstate event", ->
            assert.instanceOf event, JSDOM.dom.level3.events.Event
          it "should include state", ->
            assert.equal event.state.is, "end"


    describe "replaceState", ->
      window = null

      before (done)->
        browser = new Browser()
        browser.visit "http://localhost:3003/", ->
          browser.history.pushState { is: "start" },  null, "/start"
          browser.history.replaceState { is: "end" }, null, "/end"
          window = browser.window
          done()

      it "should not add state to history", ->
        assert.equal window.history.length, 2
      it "should change location URL", ->
        assert.equal window.location.href, "http://localhost:3003/end"

      describe "go backwards", ->
        before (done)->
          window.addEventListener "popstate", (evt)->
            window.popstate = true
          window.history.back()
          done()

        it "should change location URL", ->
          assert.equal window.location.href, "http://localhost:3003/"
        it "should not fire popstate event", ->
          assert.equal window.popstate, undefined


    describe "redirect", ->
      browser = new Browser()

      before (done)->
        browser.visit "http://localhost:3003/history/redirect", done

      it "should redirect to final destination", ->
        assert.equal browser.location, "http://localhost:3003/history/boo?redirected=true"
      it "should pass query parameter", ->
        assert.equal browser.text("title"), "Redirected"
      it "should not add location in history", ->
        assert.equal browser.history.length, 1
      it "should indicate last request followed a redirect", ->
        assert browser.redirected

    describe "redirect back", ->
      browser = new Browser()

      before (done)->
        browser.visit "http://localhost:3003/history/boo", ->
          browser.visit "http://localhost:3003/history/redirect_back"
          browser.window.document.addEventListener "DOMContentLoaded", ->
            done()

      it "should redirect to the previous path", ->
        assert.equal browser.location.href, "http://localhost:3003/history/boo"
      it "should pass query parameter", ->
        assert /Eeek!/.test(browser.text("title"))
      it "should not add location in history", ->
        assert.equal browser.history.length, 2
      it "should indicate last request followed a redirect", ->
        assert browser.redirected


  describe "location", ->

    describe "open page", ->
      browser = new Browser()

      before (done)->
        browser.visit "http://localhost:3003/", done

      it "should add page to history", ->
        assert.equal browser.history.length, 1
      it "should change location URL", ->
        assert.equal browser.location, "http://localhost:3003/"
      it "should load document": (browser)->
        assert /Tap, Tap/.test(browser.html())
      it "should set window location", ->
        assert.equal browser.window.location.href, "http://localhost:3003/"
      it "should set document location", ->
        assert.equal browser.document.location.href, "http://localhost:3003/"

    describe "open from file system", ->
      browser = new Browser()

      before (done)->
        browser.visit file_url, done

      it "should add page to history", ->
        assert.equal browser.history.length, 1
      it "should change location URL", ->
        assert.equal browser.location, file_url
      it "should load document", ->
        assert ~browser.html("title").indexOf("Insanely fast, headless full-stack testing using Node.js")
      it "should set window location", ->
        assert.equal browser.window.location.href, file_url
      it "should set document location", ->
        assert.equal browser.document.location.href, file_url

    describe "change pathname", ->
      browser = new Browser()

      before (done)->
        browser.visit "http://localhost:3003/", ->
          browser.window.location.pathname = "/history/boo"
          browser.window.document.addEventListener "DOMContentLoaded", ->
            done()

      it "should add page to history", ->
        assert.equal browser.history.length, 2
      it "should change location URL", ->
        assert.equal browser.location, "http://localhost:3003/history/boo"
      it "should load document", ->
        assert /Eeek!/.test(browser.html())

    describe "change relative href", ->
      browser = new Browser()

      before (done)->
        browser.visit "http://localhost:3003/", ->
          browser.window.location.href = "/history/boo"
          browser.window.document.addEventListener "DOMContentLoaded", ->
            done()

      it "should add page to history", ->
        assert.equal browser.history.length, 2
      it "should change location URL", ->
        assert.equal browser.location, "http://localhost:3003/history/boo"
      it "should load document", ->
        assert /Eeek!/.test(browser.html())

    describe "change hash", ->
      browser = new Browser()

      before (done)->
        browser.visit "http://localhost:3003/", ->
          browser.document.innerHTML = "Wolf"
          browser.window.addEventListener "hashchange", ->
            done()
          browser.window.location.hash = "boo"

      it "should add page to history", ->
        assert.equal browser.history.length, 2
      it "should change location URL", ->
        assert.equal browser.location, "http://localhost:3003/#boo"
      it "should not reload document", ->
        assert /Wolf/.test(browser.document.innerHTML)

    describe "assign", ->
      browser = new Browser()
      window = null

      before (done)->
        browser.visit "http://localhost:3003/", ->
          window = browser.window
          browser.window.location.assign "http://localhost:3003/history/boo"
          browser.document.addEventListener "DOMContentLoaded", ->
            done()

      it "should add page to history", ->
        assert.equal browser.history.length, 2
      it "should change location URL", ->
        assert.equal browser.location, "http://localhost:3003/history/boo"
      it "should load document", ->
        assert /Eeek!/.test(browser.html())
      it "should load document in new window", ->
        assert browser.window != window

    describe "replace", ->
      browser = new Browser()
      window = null

      before (done)->
        browser.visit "http://localhost:3003/", ->
          window = browser.window
          browser.window.location.replace "http://localhost:3003/history/boo"
          browser.window.document.addEventListener "DOMContentLoaded", ->
            done()

      it "should not add page to history", ->
        assert.equal browser.history.length, 1
      it "should change location URL", ->
        assert.equal browser.location, "http://localhost:3003/history/boo"
      it "should load document", ->
        assert /Eeek!/.test(browser.html()) 
      it "should load document in new window", ->
        assert browser.window != window

    describe "reload", ->
      browser = new Browser()
      window = null

      before (done)->
        browser.visit "http://localhost:3003/", ->
          window = browser.window
          browser.window.document.innerHTML = "Wolf"
          browser.reload()
          browser.window.document.addEventListener "DOMContentLoaded", ->
            done()

      it "should not add page to history", ->
        assert.equal browser.history.length, 1
      it "should not change location URL", ->
        assert.equal browser.location, "http://localhost:3003/"
      it "should reload document", ->
        assert /Tap, Tap/.test(browser.html())
      it "should reload document in new window", ->
        assert browser.window != window

    describe "components", ->
      location = null

      before (done)->
        browser = new Browser()
        browser.visit "http://localhost:3003/", ->
          location = browser.location
          done()

      it "should include protocol", ->
        assert.equal location.protocol, "http:"
      it "should include hostname", ->
        assert.equal location.hostname, "localhost"
      it "should include port", ->
        assert.equal location.port, 3003
      it "should include hostname and port", ->
        assert.equal location.host, "localhost:3003"
      it "should include pathname", ->
        assert.equal location.pathname, "/"
      it "should include search", ->
        assert.equal location.search, ""
      it "should include hash", ->
        assert.equal location.hash, ""

    describe "set window.location", ->
      browser = new Browser()

      before (done)->
        browser.visit "http://localhost:3003/", ->
          browser.window.location = "http://localhost:3003/history/boo"
          browser.window.document.addEventListener "DOMContentLoaded", ->
            done()

      it "should add page to history", ->
        assert.equal browser.history.length, 2
      it "should change location URL", ->
        assert.equal browser.location, "http://localhost:3003/history/boo"
      it "should load document", ->
        assert /Eeek!/.test(browser.html())

    describe "set document.location", ->
      browser = new Browser()

      before (done)->
        browser.visit "http://localhost:3003/", ->
          browser.window.document.location = "http://localhost:3003/history/boo"
          browser.window.document.addEventListener "DOMContentLoaded", ->
            done()

      it "should add page to history", ->
        assert.equal browser.history.length, 2
      it "should change location URL", ->
        assert.equal browser.location, "http://localhost:3003/history/boo"
      it "should load document", ->
        assert /Eeek!/.test(browser.html())


  describe "referer not set", ->

    describe "first page", ->
      browser = new Browser()

      before (done)->
        browser.visit "http://localhost:3003/history/referer", done

      it "should be empty", ->
        assert.equal browser.text("title"), "undefined"

      describe "second page", ->
        before (done)->
          browser.visit "http://localhost:3003/history/referer", done

        it "should point to first page", ->
          assert.equal browser.text("title"), "http://localhost:3003/history/referer"

  describe "referer set", ->

    describe "first page", ->
      browser = new Browser()

      before (done)->
        browser.visit "http://localhost:3003/history/referer", referer: "http://braindepot", done

      it "should be empty", ->
        assert.equal browser.text("title"), "http://braindepot"

      describe "second page", ->
        before (done)->
          browser.visit "http://localhost:3003/history/referer", done

        it "should point to first page", ->
          assert.equal browser.text("title"), "http://localhost:3003/history/referer"

