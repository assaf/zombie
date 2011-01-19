require "./helpers"
{ vows: vows, assert: assert, zombie: zombie, brains: brains } = require("vows")
jsdom = require("jsdom")

brains.get "/static", (req, res)-> res.send """
  <html>
    <head>
      <title>Whatever</title>
    </head>
    <body>Hello World</body>
  </html>
  """

brains.get "/scripted", (req, res)-> res.send """
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
  </html>
  """

brains.get "/living", (req, res)-> res.send """
  <html>
    <head>
      <script src="/jquery.js"></script>
      <script src="/sammy.js"></script>
      <script src="/app.js"></script>
    </head>
    <body>
      <div id="main">
        <a href="/dead">Kill</a>
        <form action="#/dead" method="post">
          <label>Email <input type="text" name="email"></label>
          <label>Password <input type="password" name="password"></label>
          <button>Sign Me Up</button>
        </form>
      </div>
      <div class="now">Walking Aimlessly</div>
    </body>
  </html>
  """

brains.get "/app.js", (req, res)-> res.send """
  Sammy("#main", function(app) {
    app.get("#/", function(context) {
      document.title = "The Living";
    });
    app.get("#/dead", function(context) {
      context.swap("The Living Dead");
    });
    app.post("#/dead", function(context) {
      document.title = "Signed up";
    });
  });
  $(function() { Sammy("#main").run("#/") });
  """

brains.get "/dead", (req, res)-> res.send """
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

brains.get "/empty", (req, res)-> res.send ""

brains.get "/soup", (req, res)-> res.send """
  <h1>Tag soup</h1>
  <p>One paragraph
  <p>And another
  """

brains.get "/useragent", (req, res)-> res.send "<body>#{req.headers["user-agent"]}</body>"

brains.get "/alert", (req, res)-> res.send """
  <script>
    alert("Hi");
    alert("Me again");
  </script>
  """

brains.get "/confirm", (req, res)-> res.send """
  <script>
    window.first = confirm("continue?");
    window.second = confirm("more?");
    window.third = confirm("silent?");
  </script>
  """

brains.get "/prompt", (req, res)-> res.send """
  <script>
    window.first = prompt("age");
    window.second = prompt("gender");
    window.third = prompt("location");
    window.fourth = prompt("weight");
  </script>
  """


vows.describe("Browser").addBatch(
  "open page":
    zombie.wants "http://localhost:3003/scripted"
      "should create HTML document": (browser)-> assert.instanceOf browser.document, jsdom.dom.level3.html.HTMLDocument
      "should load document from server": (browser)-> assert.match browser.html(), /<body>Hello World/
      "should load external scripts": (browser)->
        assert.ok jQuery = browser.window.jQuery, "window.jQuery not available"
        assert.typeOf jQuery.ajax, "function"
      "should run jQuery.onready": (browser)-> assert.equal browser.document.title, "Awesome"
      "should return status code of last request": (browser)-> assert.equal browser.statusCode, 200

  "visit":
    "successful":
      topic: ->
        brains.ready =>
          browser = new zombie.Browser
          browser.visit "http://localhost:3003/scripted", =>
            @callback null, arguments
      "should pass three arguments to callback": (args)-> assert.length args, 3
      "should not include an error": (args)-> assert.isNull args[0]
      "should pass browser to callback": (args)-> assert.ok args[1] instanceof zombie.Browser
      "should pass status code to callback": (args)-> assert.equal args[2], 200
    "error":
      topic: ->
        brains.ready =>
          browser = new zombie.Browser
          browser.visit "http://localhost:3003/missing", =>
            @callback null, arguments
      "should pass single argument to callback": (args)-> assert.length args, 1
      "should pass error to callback": (args)-> assert.ok args[0] instanceof Error
      "should include status code in error": (args)-> assert.equal args[0].statusCode, 404
    "empty page":
      zombie.wants "http://localhost:3003/empty"
        "should load document": (browser)-> assert.ok browser.body

  "event emitter":
    "successful":
      topic: ->
        brains.ready =>
          browser = new zombie.Browser
          browser.on "loaded", (browser)=> @callback null, browser
          browser.window.location = "http://localhost:3003/"
      "should fire load event": (browser)-> assert.ok browser.visit
    "error":
      topic: ->
        brains.ready =>
          browser = new zombie.Browser
          browser.on "error", (err)=> @callback null, err
          browser.window.location = "http://localhost:3003/deadend"
      "should fire onerror event": (err)->
        assert.ok err.message && err.stack
        assert.equal err.message, "Could not load document at http://localhost:3003/deadend, got 404"
    "wait over":
      topic: ->
        brains.ready =>
          browser = new zombie.Browser
          browser.on "done", (browser)=> @callback null, browser
          browser.window.location = "http://localhost:3003/"
          browser.wait()
      "should fire done event": (browser)-> assert.ok browser.visit
     
  "content selection":
    zombie.wants "http://localhost:3003/living"
      "query text":
        topic: (browser)-> browser
        "should query from document": (browser)-> assert.equal browser.text(".now"), "Walking Aimlessly"
        "should query from context": (browser)-> assert.equal browser.text(".now", browser.body), "Walking Aimlessly"
        "should query from context": (browser)-> assert.equal browser.text(".now", browser.querySelector("#main")), ""
        "should combine multiple elements": (browser)-> assert.equal browser.text("form label"), "Email Password "
      "query html":
        topic: (browser)-> browser
        "should query from document": (browser)-> assert.equal browser.html(".now"), "<div class=\"now\">Walking Aimlessly</div>"
        "should query from context": (browser)-> assert.equal browser.html(".now", browser.body), "Walking Aimlessly"
        "should query from context": (browser)-> assert.equal browser.html(".now", browser.querySelector("#main")), ""
        "should combine multiple elements": (browser)-> assert.equal browser.html("title, #main a"), "<title>The Living</title><a href=\"/dead\">Kill</a>"

  "click link":
    zombie.wants "http://localhost:3003/living"
      topic: (browser)->
        browser.clickLink "Kill", @callback
      "should change location": (_, browser)-> assert.equal browser.location, "http://localhost:3003/dead"
      "should run all events": (_, browser)-> assert.equal browser.document.title, "The Dead"
      "should return status code": (_, browser, status)-> assert.equal status, 200

  "tag soup":
    zombie.wants "http://localhost:3003/soup"
      "should parse to complete HTML": (browser)->
        assert.ok browser.querySelector("html head")
        assert.equal browser.text("html body h1"), "Tag soup"
      "should close tags": (browser)->
        paras = browser.querySelectorAll("body p").toArray().map((e)-> e.textContent.trim())
        assert.deepEqual paras, ["One paragraph", "And another"]

  "with options":
    topic: ->
      browser = new zombie.Browser
      browser.wants "http://localhost:3003/scripted", { runScripts: false }, @callback
    "should set options for the duration of the request": (browser)-> assert.equal browser.document.title, "Whatever"
    "should reset options following the request": (browser)-> assert.isTrue browser.runScripts

  "user agent":
    topic: ->
      browser = new zombie.Browser
      browser.wants "http://localhost:3003/useragent", @callback
    "should send own version to server": (browser)-> assert.match browser.text("body"), /Zombie.js\/\d\.\d/
    "should be accessible from navigator": (browser)-> assert.match browser.window.navigator.userAgent, /Zombie.js\/\d\.\d/
    "specified":
      topic: (browser)->
        browser.visit "http://localhost:3003/useragent", { userAgent: "imposter" }, @callback
      "should send user agent to server": (browser)-> assert.equal browser.text("body"), "imposter"
      "should be accessible from navigator": (browser)-> assert.equal browser.window.navigator.userAgent, "imposter"

  "URL without path":
    zombie.wants "http://localhost:3003"
      "should resolve URL": (browser)-> assert.equal browser.location.href, "http://localhost:3003"
      "should load page": (browser)-> assert.equal browser.text("title"), "Tap, Tap"

  "window.title":
    zombie.wants "http://localhost:3003/static"
      "should return the document's title": (browser)-> assert.equal browser.window.title, "Whatever"
      "should set the document's title": (browser)->
        browser.window.title = "Overwritten"
        assert.equal browser.window.title, browser.document.title

  "window.alert":
    topic: ->
      browser = new zombie.Browser
      browser.onalert (message)-> browser.window.first = true if message = "Me again"
      browser.wants "http://localhost:3003/alert", @callback
    "should record last alert show to user": (browser)-> assert.ok browser.prompted("Me again")
    "should call onalert function with message": (browser)-> assert.ok browser.window.first

  "window.confirm":
    topic: ->
      browser = new zombie.Browser
      browser.onconfirm "continue?", true
      browser.onconfirm (prompt)-> true if prompt == "more?"
      browser.wants "http://localhost:3003/confirm", @callback
    "should return canned response": (browser)-> assert.ok browser.window.first
    "should return response from function": (browser)-> assert.ok browser.window.second
    "should return false if no response/function": (browser)-> assert.equal browser.window.third, false
    "should report prompted question": (browser)->
      assert.ok browser.prompted("continue?")
      assert.ok browser.prompted("silent?")
      assert.ok !browser.prompted("missing?")

  "window.prompt":
    topic: ->
      browser = new zombie.Browser
      browser.onprompt "age", 31
      browser.onprompt (message, def)-> "unknown" if message == "gender"
      browser.onprompt "location", false
      browser.wants "http://localhost:3003/prompt", @callback
    "should return canned response": (browser)-> assert.equal browser.window.first, "31"
    "should return response from function": (browser)-> assert.equal browser.window.second, "unknown"
    "should return null if cancelled": (browser)-> assert.isNull browser.window.third
    "should return empty string if no response/function": (browser)-> assert.equal browser.window.fourth, ""
    "should report prompts": (browser)->
      assert.ok browser.prompted("age")
      assert.ok browser.prompted("gender")
      assert.ok browser.prompted("location")
      assert.ok !browser.prompted("not asked")
    
).export(module)
