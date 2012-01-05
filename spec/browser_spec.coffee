{ Vows, assert, brains, Browser } = require("./helpers")
JSDOM = require("jsdom")


Vows.describe("Browser").addBatch

  "browsing":
    topic: ->
      brains.get "/browser/scripted", (req, res)->
        res.send """
        <html>
          <head>
            <title>Whatever</title>
            <script src="/jquery.js"></script>
          </head>
          <body>Hello World</body>
          <script>
            document.title = "Nice";
            $(function() { $("title").text("Awesome") })
          </script>
          <script type="text/x-do-not-parse">
            <p>this is not valid JavaScript</p>
          </script>
        </html>
        """

      brains.get "/browser/errored", (req, res)->
        res.send """
        <script>this.is.wrong</script>
          """


    "open page":
      Browser.wants "http://localhost:3003/browser/scripted"
        "should create HTML document": (browser)->
          assert.instanceOf browser.document, JSDOM.dom.level3.html.HTMLDocument
        "should load document from server": (browser)->
          assert.match browser.html(), /<body>Hello World/
        "should load external scripts": (browser)->
          assert.ok jQuery = browser.window.jQuery, "window.jQuery not available"
          assert.typeOf jQuery.ajax, "function"
        "should run jQuery.onready": (browser)->
          assert.equal browser.document.title, "Awesome"
        "should return status code of last request": (browser)->
          assert.equal browser.statusCode, 200
        "should indicate success": (browser)->
          assert.ok browser.success
        "should have a parent": (browser)->
          assert.ok browser.window.parent


    "visit":
      "successful":
        topic: ->
          brains.ready =>
            browser = new Browser
            browser.visit "http://localhost:3003/browser/scripted", @callback
        "should call callback without error": ->
          assert.ok true
        "should pass browser to callback": (_, browser, status, errors)->
          assert.instanceOf browser, Browser
        "should pass status code to callback": (_, browser, status, errors)->
          assert.equal status, 200
        "should indicate success": (browser)->
          assert.ok browser.success
        "should pass zero errors to callback": (_, browser, status, errors)->
          assert.lengthOf errors, 0
        "should reset browser errors": (_, browser, status, errors)->
          assert.lengthOf browser.errors, 0
        "should have a resources object": (browser)->
          assert.ok browser.resources

      "with error":
        topic: ->
          brains.ready =>
            browser = new Browser
            browser.visit "http://localhost:3003/browser/errored", @callback
        "should call callback without error": ->
          assert.ok true
        "should indicate success": (browser)->
          assert.ok browser.success
        "should pass errors to callback": (_, browser, status, errors)->
          assert.lengthOf errors, 1
          assert.equal errors[0].message, "Cannot read property 'wrong' of undefined"
        "should set browser errors": (_, browser, status, errors)->
          assert.lengthOf browser.errors, 1
          assert.equal browser.errors[0].message, "Cannot read property 'wrong' of undefined"

      "404":
        topic: ->
          brains.ready =>
            browser = new Browser
            browser.visit "http://localhost:3003/browser/missing", @callback
        "should call callback without error": ->
          assert.ok true
        "should return status code": (_, browser, status)->
          assert.equal status, 404
        "should not indicate success": (browser)->
          assert.ok !browser.success
        "should capture response document": (browser)->
          assert.equal browser.source, "Cannot GET /browser/missing" # Express output
        "should return response document form text method": (browser)->
          assert.equal browser.text(), "Cannot GET /browser/missing" # Express output
        "should return response document form html method": (browser)->
          assert.equal browser.html(), "Cannot GET /browser/missing" # Express output

      "500":
        topic: ->
          brains.get "/browser/500", (req, res)->
            res.send "Ooops, something went wrong", 500
          brains.ready =>
            browser = new Browser
            browser.visit "http://localhost:3003/browser/500", @callback
        "should call callback without error": ->
          assert.ok true
        "should return status code 500": (_, browser, status)->
          assert.equal status, 500
        "should not indicate success": (browser)->
          assert.ok !browser.success
        "should capture response document": (browser)->
          assert.equal browser.source, "Ooops, something went wrong"
        "should return response document form text method": (browser)->
          assert.equal browser.text(), "Ooops, something went wrong"
        "should return response document form html method": (browser)->
          assert.equal browser.html(), "Ooops, something went wrong"

      "empty page":
        topic: ->
          brains.get "/browser/empty", (req, res)->
            res.send ""
          browser = new Browser
          browser.wants "http://localhost:3003/browser/empty", @callback
        "should load document": (browser)->
          assert.ok browser.body
        "should indicate success": (browser)->
          assert.ok browser.success

.addBatch

    "event emitter":
      "successful":
        topic: ->
          brains.ready =>
            browser = new Browser
            browser.on "loaded", =>
              @callback null, browser
            browser.window.location = "http://localhost:3003/browser/scripted"
        "should fire load event": (browser)->
          assert.ok browser.visit

      "wait over":
        topic: ->
          brains.ready =>
            browser = new Browser
            browser.on "done", (browser)=>
              @callback null, browser
            browser.window.location = "http://localhost:3003/browser/scripted"
            browser.wait()
        "should fire done event": (browser)->
          assert.ok browser.visit

      "error":
        topic: ->
          brains.ready =>
            browser = new Browser
            browser.on "error", (error)=>
              @callback null, error
            browser.window.location = "http://localhost:3003/browser/errored"
        "should fire onerror event": (err)->
          assert.ok err.message && err.stack
          assert.equal err.message, "Cannot read property 'wrong' of undefined"


.addBatch

  "with options":
    "per call":
      topic: ->
        browser = new Browser
        browser.wants "http://localhost:3003/browser/scripted", { runScripts: false }, @callback
      "should set options for the duration of the request": (browser)->
        assert.equal browser.document.title, "Whatever"
      "should reset options following the request": (browser)->
        assert.isTrue browser.runScripts

    "global":
      topic: ->
        Browser.site = "http://localhost:3003"
        browser = new Browser
        browser.wants "/browser/scripted", @callback
      "should set browser options from global options": (browser)->
        assert.equal browser.site, "http://localhost:3003"
        assert.equal browser.document.title, "Awesome"
      teardown: ->
        Browser.site = null

  "user agent":
    topic: ->
      brains.get "/browser/useragent", (req, res)->
        res.send "<html><body>#{req.headers["user-agent"]}</body></html>"
      browser = new Browser
      browser.wants "http://localhost:3003/browser/useragent", @callback
    "should send own version to server": (browser)->
      assert.match browser.text("body"), /Zombie.js\/\d\.\d/
    "should be accessible from navigator": (browser)->
      assert.match browser.window.navigator.userAgent, /Zombie.js\/\d\.\d/

    "specified":
      topic: (browser)->
        browser.visit "http://localhost:3003/browser/useragent", { userAgent: "imposter" }, @callback
      "should send user agent to server": (browser)->
        assert.equal browser.text("body"), "imposter"
      "should be accessible from navigator": (browser)->
        assert.equal browser.window.navigator.userAgent, "imposter"


.addBatch

  "click link":
    topic: ->
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
      browser = new Browser(waitFor: 700)
      browser.wants "http://localhost:3003/browser/head", =>
        browser.clickLink "Smash", @callback

    "should change location": (_, browser)->
      assert.equal browser.location, "http://localhost:3003/browser/headless"
    "should run all events": (_, browser)->
      assert.equal browser.document.title, "The Dead"
    "should return status code": (_, browser, status)->
      assert.equal status, 200


  ###
  # NOTE: htmlparser doesn't handle tag soup.
  "tag soup using HTML5 parser":
    topic: ->
      brains.get "/browser/soup", (req, res)-> res.send """
        <h1>Tag soup</h1>
        <p>One paragraph
        <p>And another
        """
      browser = new Browser
      browser.wants "http://localhost:3003/browser/soup", { htmlParser: require("html5").HTML5 }, @callback
    "should parse to complete HTML": (browser)->
      assert.ok browser.querySelector("html head")
      assert.equal browser.text("html body h1"), "Tag soup"
    "should close tags": (browser)->
      paras = browser.querySelectorAll("body p").toArray().map((e)-> e.textContent.trim())
      assert.deepEqual paras, ["One paragraph", "And another"]
  ###


.addBatch


  "fork":
    topic: ->
      brains.get "/browser/living", (req, res)->
        res.send """
        <html><script>dead = "almost"</script></html>
        """
      brains.get "/browser/dead", (req, res)->
        res.send """
        <html><script>dead = "very"</script></html>
        """

      browser = new Browser
      browser.wants "http://localhost:3003/browser/living", =>
        browser.cookies("www.localhost").update("foo=bar; domain=.localhost")
        browser.localStorage("www.localhost").setItem("foo", "bar")
        browser.sessionStorage("www.localhost").setItem("baz", "qux")

        forked = browser.fork()
        forked.visit "http://localhost:3003/browser/dead", (err)=>
          browser.cookies("www.localhost").update("foo=baz; domain=.localhost")
          browser.localStorage("www.localhost").setItem("foo", "new")
          browser.sessionStorage("www.localhost").setItem("baz", "value")
          @callback null, [forked, browser]

    "should not be the same object": ([forked, browser])->
      assert.notStrictEqual browser, forked
    "should have two browser objects": ([forked, browser])->
      assert.isNotNull forked
      assert.isNotNull browser
    "should navigate independently": ([forked, browser])->
      assert.equal browser.location.href, "http://localhost:3003/browser/living"
      assert.equal forked.location, "http://localhost:3003/browser/dead"
    "should manipulate cookies independently": ([forked, browser])->
      assert.equal browser.cookies("localhost").get("foo"), "baz"
      assert.equal forked.cookies("localhost").get("foo"), "bar"
    "should manipulate storage independently": ([forked, browser])->
      assert.equal browser.localStorage("www.localhost").getItem("foo"), "new"
      assert.equal browser.sessionStorage("www.localhost").getItem("baz"), "value"
      assert.equal forked.localStorage("www.localhost").getItem("foo"), "bar"
      assert.equal forked.sessionStorage("www.localhost").getItem("baz"), "qux"
    "should have independent history": ([forked, browser])->
      assert.equal "http://localhost:3003/browser/living", browser.location.href
      assert.equal "http://localhost:3003/browser/dead", forked.location.href
    "should have independent globals": ([forked, browser])->
      assert.equal browser.evaluate("window.dead"), "almost"
      assert.equal forked.evaluate("window.dead"), "very"
    "should clone history from source": ([forked, browser])->
      assert.equal "http://localhost:3003/browser/dead", forked.location.href
      forked.window.history.back()
      assert.equal "http://localhost:3003/browser/living", forked.location.href


.export(module)
