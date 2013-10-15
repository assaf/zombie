{ assert, brains, Browser } = require("./helpers")
JSDOM = require("jsdom")
HTML5 = require("html5")


describe "Browser", ->

  browser = null
  before (done)->
    browser = Browser.create()
    brains.ready(done)

  before ->
    brains.get "/browser/scripted", (req, res)->
      res.send """
      <html>
        <head>
          <title>Whatever</title>
          <script src="/jquery.js"></script>
        </head>
        <body>
          <h1>Hello World</h1>
          <script>
            document.title = "Nice";
            $(function() { $("title").text("Awesome") })
          </script>
          <script type="text/x-do-not-parse">
            <p>this is not valid JavaScript</p>
          </script>
        </body>
      </html>
      """

    brains.get "/browser/errored", (req, res)->
      res.send """
        <html>
          <head>
            <script>this.is.wrong</script>
          </head>
        </html>
      """


  describe "browsing", ->

    describe "open page", ->
      before (done)->
        browser.visit("http://localhost:3003/browser/scripted", done)

      it "should create HTML document", ->
        assert browser.document instanceof JSDOM.dom.level3.html.HTMLDocument
      it "should load document from server", ->
        browser.assert.text "body h1", "Hello World"
      it "should load external scripts", ->
        assert jQuery = browser.window.jQuery, "window.jQuery not available"
        assert.equal typeof jQuery.ajax, "function"
      it "should run jQuery.onready", ->
        browser.assert.text "title", "Awesome"
      it "should return status code of last request", ->
        browser.assert.success()
      it "should indicate success", ->
        assert browser.success
      it "should have a parent", ->
        assert browser.window.parent


    describe "visit", ->

      describe "successful", ->
        status = error = errors = null

        before (done)->
          Browser.visit "http://localhost:3003/browser/scripted", (@error, @browser)=>
            done()

        it "should call callback without error", ->
          assert !@error
        it "should pass browser to callback", ->
          assert @browser instanceof Browser
        it "should pass status code to callback", ->
          @browser.assert.success()
        it "should indicate success", ->
          assert @browser.success
        it "should reset browser errors", ->
          assert.equal @browser.errors.length, 0
        it "should have a resources object", ->
          assert @browser.resources

      describe "with error", ->
        before (done)->
          Browser.visit "http://localhost:3003/browser/errored", (@error, @browser)=>
            done()

        it "should call callback with error", ->
          assert @error
          assert @error.constructor.name == "TypeError"
        it "should indicate success", ->
          @browser.assert.success()
        it "should set browser errors", ->
          assert.equal @browser.errors.length, 1
          assert.equal @browser.errors[0].message, "Cannot read property 'wrong' of undefined"

      describe "404", ->
        before (done)->
          Browser.visit "http://localhost:3003/browser/missing", (@error, @browser)=>
            done()

        it "should call with error", ->
          assert @error instanceof Error
        it "should return status code", ->
          @browser.assert.status 404
        it "should not indicate success", ->
          assert !@browser.success
        it "should capture response document", ->
          assert.equal @browser.source, "Cannot GET /browser/missing" # Express output
        it "should return response document with the error", ->
          @browser.assert.text "body", "Cannot GET /browser/missing" # Express output

      describe "500", ->
        before ->
          brains.get "/browser/500", (req, res)->
            res.send "Ooops, something went wrong", 500

        before (done)->
          Browser.visit "http://localhost:3003/browser/500", (@error, @browser)=>
            done()

        it "should call callback with error", ->
          assert @error instanceof Error
        it "should return status code 500", ->
          @browser.assert.status 500
        it "should not indicate success", ->
          assert !@browser.success
        it "should capture response document", ->
          assert.equal @browser.source, "Ooops, something went wrong"
        it "should return response document with the error", ->
          @browser.assert.text "body", "Ooops, something went wrong"

      describe "empty page", ->
        before ->
          brains.get "/browser/empty", (req, res)->
            res.send ""

        before (done)->
          Browser.visit "http://localhost:3003/browser/empty", (@error, @browser)=>
            done()

        it "should load document", ->
          assert @browser.body
        it "should indicate success", ->
          @browser.assert.success()


    describe "event emitter", ->

      describe "successful", ->
        before (done)->
          browser.once "loaded", (@document)=>
            done()
          browser.visit("http://localhost:3003/browser/scripted")

        it "should fire load event with document object", ->
          assert @document.addEventListener

      describe "wait over", ->

        before (done)->
          browser.once("done", done)
          browser.location = "http://localhost:3003/browser/scripted"
          browser.wait()

        it "should fire done event", ->
          assert true

      describe "error", ->
        before (done)->
          browser.once "error", (@error)=>
            done()
          browser.location = "http://localhost:3003/browser/errored"
          browser.wait()

        it "should fire onerror event with error", ->
          assert @error.message && @error.stack
          assert.equal @error.message, "Cannot read property 'wrong' of undefined"


  describe "with options", ->

    describe "per call", ->
      before (done)->
        browser.visit("http://localhost:3003/browser/scripted", { features: "no-scripts" }, done)

      it "should set options for the duration of the request", ->
        browser.assert.text "title", "Whatever"
      it "should reset options following the request", ->
        assert.equal browser.features, "scripts no-css no-img iframe"

    describe "global", ->
      newBrowser = null

      before (done)->
        @features = Browser.default.features
        Browser.default.features = "no-scripts"
        newBrowser = Browser.create()
        newBrowser.visit("/browser/scripted", done)

      it "should set browser options from global options", ->
        newBrowser.assert.text "title", "Whatever"

      after ->
        newBrowser.destroy()
        Browser.default.features = @features

    describe "user agent", ->

      before ->
        brains.get "/browser/useragent", (req, res)->
          res.send "<html><body>#{req.headers["user-agent"]}</body></html>"

      before (done)->
        browser.visit("http://localhost:3003/browser/useragent", done)

      it "should send own version to server", ->
        browser.assert.text "body", /Zombie.js\/\d\.\d/
      it "should be accessible from navigator", ->
        assert /Zombie.js\/\d\.\d/.test(browser.window.navigator.userAgent)

      describe "specified", ->

        before (done)->
          browser.visit("http://localhost:3003/browser/useragent", { userAgent: "imposter" }, done)

        it "should send user agent to server", ->
          browser.assert.text "body", "imposter"
        it "should be accessible from navigator", ->
          assert.equal browser.window.navigator.userAgent, "imposter"

    describe "custom headers", ->

      before ->
        brains.get "/browser/custom_headers", (req, res)->
          res.send "<html><body>#{req.headers["x-custom-header"]}</body></html>"

      describe "specified", ->

        before (done)->
          browser.headers =
            "x-custom-header": "dummy"
          browser.visit("http://localhost:3003/browser/custom_headers", done)

        it "should send the custom header to server", ->
          browser.assert.text "body", "dummy"

        after ->
          delete browser.headers["x-custom-header"]


  describe "click link", ->

    before ->
      brains.get "/browser/head", (req, res)->
        res.send """
        <html>
          <body>
            <a href="/browser/headless">Smash</a>
          </body>
        </html>
        """
      brains.get "/browser/headless", (req, res)->
        res.send """
        <html>
          <head>
            <script src="/jquery.js"></script>
          </head>
          <body>
            <script>
              $(function() { document.title = "The Dead" });
            </script>
          </body>
        </html>
        """

    before (done)->
      browser.visit "http://localhost:3003/browser/head", ->
        browser.clickLink("Smash", done)

    it "should change location", ->
      browser.assert.url "http://localhost:3003/browser/headless"
    it "should run all events", ->
      browser.assert.text "title", "The Dead"
    it "should return status code", ->
      browser.assert.success()


  describe "follow redirect", ->

    before ->
      brains.get "/browser/killed", (req, res)->
        res.send """
        <html>
          <body>
            <form action="/browser/alive" method="post">
              <input type="submit" name="Submit">
            </form>
          </body>
        </html>
        """
      brains.post "/browser/alive", (req, res)->
        res.redirect "/browser/killed"

    before (done)->
      browser.visit "http://localhost:3003/browser/killed", ->
        browser.pressButton("Submit", done)

    it "should be at initial location", ->
      browser.assert.url "http://localhost:3003/browser/killed"
    it "should have followed a redirection", ->
      browser.assert.redirected()
    it "should return status code", ->
      browser.assert.success()


  # NOTE: htmlparser doesn't handle tag soup.
  if Browser.htmlParser == HTML5
    describe "tag soup using HTML5 parser", ->

      before ->
        brains.get "/browser/soup", (req, res)-> res.send """
          <h1>Tag soup</h1>
          <p>One paragraph
          <p>And another
          """

      before (done)->
        browser.visit "http://localhost:3003/browser/soup", ->
          done()

      it "should parse to complete HTML", ->
        browser.assert.element "html head"
        browser.assert.text "html body h1", "Tag soup"
      it "should close tags", ->
        browser.assert.text "body p", "One paragraph And another"

  describe "comments", ->

    before ->
      brains.get "/browser/comment", (req, res)-> res.send """
        This is <!-- a comment, not --> plain text
        """

    before (done)->
      browser.visit "http://localhost:3003/browser/comment", ->
        done()

    it "should not show up as text node", ->
      browser.assert.text "body", "This is plain text"


  describe "load HTML string", ->
    before (done)->
      browser.load("""
          <html>
            <head>
              <title>Load</title>
            </head>
            <body>
              <div id="main"></div>
              <script>document.title = document.title + " html"</script>
            </body>
          </html>
        """)
          .then(done, done)

    it "should use about:blank URL", ->
      browser.assert.url "about:blank"

    it "should load document", ->
      browser.assert.element "#main"

    it "should execute JavaScript", ->
      browser.assert.text "title", "Load html"


  describe "multiple visits to same URL", ->
    before (done)->
      browser.visit "http://localhost:3003/browser/scripted", done
    before (done)->
      browser.assert.text "body h1", "Hello World"
      browser.visit("http://localhost:3003/", (done))
    before (done)->
      browser.assert.text "title", "Tap, Tap"
      browser.visit("http://localhost:3003/browser/scripted", done)

    it "should load document from server", ->
      browser.assert.text "body h1", "Hello World"


  describe "windows", ->

    describe "open window to page", ->
      window = null

      before ->
        brains.get "/browser/popup", (req, res)-> res.send """
          <h1>Popup window</h1>
          """

      before (done)->
        browser.tabs.closeAll()
        browser.visit "about:blank", ->
          window = browser.window.open("http://localhost:3003/browser/popup", "popup")
          browser.wait(done)

      it "should create new window", ->
        assert window

      it "should set window name", ->
        assert.equal window.name, "popup"

      it "should set window closed to false", ->
        assert.equal window.closed, false

      it "should load page", ->
        browser.assert.text "h1", "Popup window"


      describe "call open on named window", ->
        named = null

        before ->
          named = browser.window.open(null, "popup")

        it "should return existing window", ->
          assert.equal named, window

        it "should not change document location", ->
          assert.equal named.location.href, "http://localhost:3003/browser/popup"


    describe "open one window from another", ->

      before ->
        brains.get "/browser/pop", (req, res)-> res.send """
          <script>
            document.title = window.open("/browser/popup", "popup")
          </script>
          """
        brains.get "/browser/popup", (req, res)-> res.send """
          <h1>Popup window</h1>
          """

      before (done)->
        browser.tabs.closeAll()
        browser.visit("http://localhost:3003/browser/pop", done)

      it "should open both windows", ->
        assert.equal browser.tabs.length, 2
        assert.equal browser.tabs[0].name, ""
        assert.equal browser.tabs[1].name, "popup"

      it "should switch to last window", ->
        assert.equal browser.window, browser.tabs[1]

      it "should reference opener from opened window", ->
        assert.equal browser.window.opener, browser.tabs[0]


      describe "and close it", ->
        closedWindow = null

        before ->
          closedWindow = browser.window
          browser.window.close()

        it "should close that window", ->
          assert.equal browser.tabs.length, 1
          assert.equal browser.tabs[0].name, ""
          assert !browser.tabs[1]

        it "should set the `closed` property to `true`", ->
          assert.equal closedWindow.closed, true

        it "should switch to last window", ->
          assert.equal browser.window, browser.tabs[0]


        describe "and close main window", ->
          before ->
            browser.open()
            browser.window.close()

          it "should keep that window", ->
            assert.equal browser.tabs.length, 1
            assert.equal browser.tabs[0].name, ""
            assert.equal browser.window, browser.tabs[0]

          describe "and close browser", ->
            before ->
              assert.equal browser.tabs.length, 1
              browser.close()

            it "should close all window", ->
              assert.equal browser.tabs.length, 0


  describe "fork", ->
    forked = null

    before ->
      brains.get "/browser/living", (req, res)->
        res.send """
        <html><script>dead = "almost"</script></html>
        """
      brains.get "/browser/dead", (req, res)->
        res.send """
        <html><script>dead = "very"</script></html>
        """

    before (done)->
      browser.visit "http://localhost:3003/browser/living", ->
        browser.setCookie(name: "foo", value: "bar")
        browser.localStorage("www.localhost").setItem("foo", "bar")
        browser.sessionStorage("www.localhost").setItem("baz", "qux")
        forked = browser.fork()
        forked.visit "http://localhost:3003/browser/dead", (err)->
          forked.setCookie(name: "foo", value: "baz")
          forked.localStorage("www.localhost").setItem("foo", "new")
          forked.sessionStorage("www.localhost").setItem("baz", "value")
          done()

    it "should have two browser objects", ->
      assert forked && browser
      assert browser != forked
    it "should use same options", ->
      assert.equal browser.debug,       forked.debug
      assert.equal browser.htmlParser,  forked.htmlParser
      assert.equal browser.maxWait,     forked.maxWait
      assert.equal browser.proxy,       forked.proxy
      assert.equal browser.referer,     forked.referer
      assert.equal browser.features,    forked.features
      assert.equal browser.silent,      forked.silent
      assert.equal browser.site,        forked.site
      assert.equal browser.userAgent,   forked.userAgent
      assert.equal browser.waitFor,     forked.waitFor
      assert.equal browser.name,        forked.name
    it "should navigate independently", ->
      assert.equal browser.location.href, "http://localhost:3003/browser/living"
      assert.equal forked.location, "http://localhost:3003/browser/dead"
    it "should manipulate cookies independently", ->
      assert.equal browser.getCookie(name: "foo"), "bar"
      assert.equal forked.getCookie(name: "foo"), "baz"
    it "should manipulate storage independently", ->
      assert.equal browser.localStorage("www.localhost").getItem("foo"), "bar"
      assert.equal browser.sessionStorage("www.localhost").getItem("baz"), "qux"
      assert.equal forked.localStorage("www.localhost").getItem("foo"), "new"
      assert.equal forked.sessionStorage("www.localhost").getItem("baz"), "value"
    it "should have independent history", ->
      assert.equal "http://localhost:3003/browser/living", browser.location.href
      assert.equal "http://localhost:3003/browser/dead", forked.location.href
    it "should have independent globals", ->
      assert.equal browser.evaluate("window.dead"), "almost"
      assert.equal forked.evaluate("window.dead"), "very"

    describe.skip "history", ->
      it "should clone from source", ->
        assert.equal "http://localhost:3003/browser/dead", forked.location.href
        forked.window.history.back()
        assert.equal "http://localhost:3003/browser/living", forked.location.href


  after ->
    browser.destroy()
