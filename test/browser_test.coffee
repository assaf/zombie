{ assert, brains, Browser } = require("./helpers")
JSDOM = require("jsdom")


describe "Browser", ->

  before (done)->
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

    brains.ready done


  describe "browsing", ->

    describe "open page", ->
      browser = new Browser()
      before (done)->
        browser.visit "http://localhost:3003/browser/scripted", done 

      it "should create HTML document", ->
        assert browser.document instanceof JSDOM.dom.level3.html.HTMLDocument
      it "should load document from server", ->
        assert.equal browser.text("body h1"), "Hello World"
      it "should load external scripts", ->
        assert jQuery = browser.window.jQuery, "window.jQuery not available"
        assert.equal typeof jQuery.ajax, "function"
      it "should run jQuery.onready", ->
        assert.equal browser.document.title, "Awesome"
      it "should return status code of last request", ->
        assert.equal browser.statusCode, 200
      it "should indicate success", ->
        assert browser.success
      it "should have a parent", ->
        assert browser.window.parent

    describe "visit", ->

      describe "successful", ->
        browser = new Browser()
        status = error = errors = null

        before (done)->
          browser.visit "http://localhost:3003/browser/scripted", ->
            [error, browser, status, errors] = arguments
            done()

        it "should call callback without error", ->
          assert !error
        it "should pass browser to callback", ->
          assert browser instanceof Browser
        it "should pass status code to callback", ->
          assert.equal status, 200
        it "should indicate success", ->
          assert browser.success
        it "should pass zero errors to callback", ->
          assert.equal errors.length, 0
        it "should reset browser errors", ->
          assert.equal browser.errors.length, 0
        it "should have a resources object", ->
          assert browser.resources

      describe "with error", ->
        browser = new Browser()
        status = error = errors = null

        before (done)->
          browser.visit "http://localhost:3003/browser/errored", ->
            [error, browser, status, errors] = arguments
            done()

        it "should call callback without error", ->
          console.dir error
          assert error instanceof Error
        it "should indicate success", ->
          assert browser.success
        it "should pass errors to callback", ->
          console.log errors
          assert.equal errors.length, 1
          assert.equal errors[0].message, "Cannot read property 'wrong' of undefined"
        it "should set browser errors", ->
          assert.equal browser.errors.length, 1
          assert.equal browser.errors[0].message, "Cannot read property 'wrong' of undefined"

      describe "404", ->
        browser = new Browser()
        status = error = errors = null

        before (done)->
          browser.visit "http://localhost:3003/browser/missing", ->
            [error, browser, status, errors] = arguments
            done()

        it "should call with error", ->
          assert error instanceof Error
        it "should return status code", ->
          assert.equal status, 404
        it "should not indicate success", ->
          assert !browser.success
        it "should capture response document", ->
          assert.equal browser.source, "Cannot GET /browser/missing" # Express output
        it "should return response document with the error", ->
          assert.equal browser.text("body"), "Cannot GET /browser/missing" # Express output

      describe "500", ->
        browser = new Browser()
        status = error = errors = null

        before (done)->
          brains.get "/browser/500", (req, res)->
            res.send "Ooops, something went wrong", 500
          browser.visit "http://localhost:3003/browser/500", ->
            [error, browser, status, errors] = arguments
            done()

        it "should call callback with error", ->
          assert error instanceof Error
        it "should return status code 500", ->
          assert.equal status, 500
        it "should not indicate success", ->
          assert !browser.success
        it "should capture response document", ->
          assert.equal browser.source, "Ooops, something went wrong"
        it "should return response document with the error", ->
          assert.equal browser.text("body"), "Ooops, something went wrong"

      describe "empty page", ->
        browser = new Browser()
        status = error = errors = null

        before (done)->
          brains.get "/browser/empty", (req, res)->
            res.send ""
          browser.visit "http://localhost:3003/browser/empty", ->
            [error, browser, status, errors] = arguments
            done()

        it "should load document", ->
          assert browser.body
        it "should indicate success", ->
          assert browser.success


    describe "event emitter", ->

      describe "successful", ->
        browser = new Browser()
        args = null

        before (done)->
          browser.on "loaded", ->
            args = arguments
            done()
          browser.window.location = "http://localhost:3003/browser/scripted"

        it "should fire load event with browser", ->
          assert args
          assert args[0].visit

      describe "wait over", ->
        browser = new Browser()

        before (done)->
          browser.on "done", ->
            done()
          browser.window.location = "http://localhost:3003/browser/scripted"
          browser.wait()

        it "should fire done event", ->
          assert true

      describe "error", ->
        browser = new Browser()
        args = null

        before (done)->
          browser.on "error", ->
            args = arguments
            done()
          browser.window.location = "http://localhost:3003/browser/errored"

        it "should fire onerror event with error", ->
          assert args
          error = args[0]
          assert error.message && error.stack
          assert.equal error.message, "Cannot read property 'wrong' of undefined"


  describe "with options", ->

    describe "per call", ->
      browser = new Browser()
      before (done)->
        browser.visit "http://localhost:3003/browser/scripted", { runScripts: false }, done

      it "should set options for the duration of the request", ->
        assert.equal browser.document.title, "Whatever"
      it "should reset options following the request", ->
        assert.equal browser.runScripts, true

    describe "global", ->
      Browser.site = "http://localhost:3003"
      browser = new Browser()
      before (done)->
        browser.visit "/browser/scripted", done

      it "should set browser options from global options", ->
        assert.equal browser.site, "http://localhost:3003"
        assert.equal browser.document.title, "Awesome"

      after ->
        Browser.site = null

    describe  "global with file: url scheme", ->
      Browser.site = "file://#{__dirname}/data/"
      browser = new Browser()
      before (done)->
        browser.visit "index.html", done

      it "should set the browser options from global options", ->
        assert.equal browser.site, "file://#{__dirname}/data/"
        assert /Insanely fast, headless/.test(browser.document.title)

      after ->
        Browser.site = null

    describe "user agent", ->
      browser = new Browser()

      before (done)->
        brains.get "/browser/useragent", (req, res)->
          res.send "<html><body>#{req.headers["user-agent"]}</body></html>"
        browser.visit "http://localhost:3003/browser/useragent", done

      it "should send own version to server", ->
        assert /Zombie.js\/\d\.\d/.test(browser.text("body")) 
      it "should be accessible from navigator", ->
        assert /Zombie.js\/\d\.\d/.test(browser.window.navigator.userAgent)

      describe "specified", ->
        before (done)->
          browser.visit "http://localhost:3003/browser/useragent", { userAgent: "imposter" }, done

        it "should send user agent to server", ->
          assert.equal browser.text("body"), "imposter"
        it "should be accessible from navigator", ->
          assert.equal browser.window.navigator.userAgent, "imposter"


  describe "click link", ->
    browser = new Browser()

    before (done)->
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
      brains.ready done

    before (done)->
      browser.visit "http://localhost:3003/browser/head", ->
        browser.clickLink "Smash", done

    it "should change location", ->
      assert.equal browser.location, "http://localhost:3003/browser/headless"
    it "should run all events", ->
      assert.equal browser.document.title, "The Dead"
    it "should return status code", ->
      assert.equal browser.statusCode, 200

  describe "follow express redirect", ->
    browser = new Browser()

    before (done)->
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
      brains.ready done

    before (done)->
      browser.visit "http://localhost:3003/browser/killed", ->
        browser.pressButton "Submit", done

    it "should be at initial location", ->
      assert.equal browser.location, "http://localhost:3003/browser/killed"
    it "should have followed a redirection", ->
      assert.equal browser.redirected, true
    it "should return status code", ->
      assert.equal browser.statusCode, 200


  # NOTE: htmlparser doesn't handle tag soup.
  describe "tag soup using HTML5 parser", ->
    browser = new Browser()

    before (done)->
      brains.get "/browser/soup", (req, res)-> res.send """
        <h1>Tag soup</h1>
        <p>One paragraph
        <p>And another
        """
      browser.visit "http://localhost:3003/browser/soup", ->
        done()

    it "should parse to complete HTML", ->
      assert.ok browser.querySelector("html head")
      assert.equal browser.text("html body h1"), "Tag soup"
    it "should close tags", ->
      paras = browser.querySelectorAll("body p").map((e)-> e.textContent.trim())
      assert.deepEqual paras, ["One paragraph", "And another"]

  describe "comments", ->
    browser = new Browser()

    before (done)->
      brains.get "/browser/comment", (req, res)-> res.send """
        This is <!-- a comment, not --> plain text
        """
      browser.visit "http://localhost:3003/browser/comment", ->
        done()

    it "should not show up as text node", ->
      assert.equal browser.text("body"), "This is  plain text"


  describe "fork", ->
    browser = new Browser
    forked = null

    before (done)->
      brains.get "/browser/living", (req, res)->
        res.send """
        <html><script>dead = "almost"</script></html>
        """
      brains.get "/browser/dead", (req, res)->
        res.send """
        <html><script>dead = "very"</script></html>
        """
      brains.ready done

    before (done)->
      browser.visit "http://localhost:3003/browser/living", ->
        browser.cookies("www.localhost").update("foo=bar; domain=.localhost")
        browser.localStorage("www.localhost").setItem("foo", "bar")
        browser.sessionStorage("www.localhost").setItem("baz", "qux")

        forked = browser.fork()
        forked.visit "http://localhost:3003/browser/dead", (err)->
          forked.cookies("www.localhost").update("foo=baz; domain=.localhost")
          forked.localStorage("www.localhost").setItem("foo", "new")
          forked.sessionStorage("www.localhost").setItem("baz", "value")
          done()

    it "should not be the same object", ->
      assert browser != forked
    it "should have two browser objects", ->
      assert forked
      assert browser
    it "should navigate independently", ->
      assert.equal browser.location.href, "http://localhost:3003/browser/living"
      assert.equal forked.location, "http://localhost:3003/browser/dead"
    it "should manipulate cookies independently", ->
      assert.equal browser.cookies("localhost").get("foo"), "bar"
      assert.equal forked.cookies("localhost").get("foo"), "baz"
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
    it "should clone history from source", ->
      assert.equal "http://localhost:3003/browser/dead", forked.location.href
      forked.window.history.back()
      assert.equal "http://localhost:3003/browser/living", forked.location.href

