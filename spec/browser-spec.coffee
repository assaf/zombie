require("./helpers")
{ vows: vows, assert: assert, zombie: zombie, brains: brains } = require("vows")
jsdom = require("jsdom")
fs = require("fs")


brains.get "/scripted", (req, res)-> res.send """
  <html>
    <head>
      <title>Whatever</title>
      <script src="/jquery.js"></script>
    </head>
    <body>Hello World</body>
    <script>
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

brains.get "/soup", (req, res)-> res.send """
  <h1>Tag soup</h1>
  <p>One paragraph
  <p>And another
  """

brains.get "/script/write", (req, res)-> res.send """
  <html>
    <head>
      <script>document.write(unescape(\'%3Cscript src="/jquery.js"%3E%3C/script%3E\'));</script>
    </head>
    <body>
      <script>
        $(function() { document.title = "Script document.write" });
      </script>
    </body>
  </html>
  """

brains.get "/script/append", (req, res)-> res.send """
  <html>
    <head>
      <script>
        var s = document.createElement('script'); s.type = 'text/javascript'; s.async = true;
        s.src = '/jquery.js';
        (document.getElementsByTagName('head')[0] || document.getElementsByTagName('body')[0]).appendChild(s);
      </script>
    </head>
    <body>
      <script>
        $(function() { document.title = "Script appendChild" });
      </script>
    </body>
  </html>
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

  "run app":
    zombie.wants "http://localhost:3003/living"
      "should execute route": (browser)-> assert.equal browser.document.title, "The Living"
      "should change location": (browser)-> assert.equal browser.location, "http://localhost:3003/living#/"
      "move around":
        topic: (browser)->
          browser.window.location.hash = "/dead"
          browser.wait @callback
        "should execute route": (browser)-> assert.equal browser.text("#main"), "The Living Dead"
        "should change location": (browser)-> assert.equal browser.location, "http://localhost:3003/living#/dead"

  "event emitter":
    "successful":
      topic: ->
        browser = new zombie.Browser
        browser.on "loaded", (browser)=> @callback null, browser
        browser.wants "http://localhost:3003/"
      "should fire load event": (browser)-> assert.ok browser.visit
    "error":
      topic: ->
        browser = new zombie.Browser
        browser.on "error", (err)=> @callback null, err
        browser.wants "http://localhost:3003/deadend"
      "should fire onerror event": (err)->
        assert.ok err.message && err.stack
        assert.equal err.message, "Could not load document at http://localhost:3003/deadend, got 404"
    "wait over":
      topic: ->
        browser = new zombie.Browser
        browser.on "drain", (browser)=> @callback null, browser
        browser.wants "http://localhost:3003/"
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
      "should change location": (browser)-> assert.equal browser.location, "http://localhost:3003/dead"
      "should run all events": (browser)-> assert.equal browser.document.title, "The Dead"

  "live events":
    zombie.wants "http://localhost:3003/living"
      topic: (browser)->
        browser.fill("Email", "armbiter@zombies").fill("Password", "br41nz").
          pressButton "Sign Me Up", @callback
      "should change location": (browser)-> assert.equal browser.location, "http://localhost:3003/living#/"
      "should process event": (browser)-> assert.equal browser.document.title, "Signed up"

  "tag soup":
    zombie.wants "http://localhost:3003/soup"
      "should parse to complete HTML": (browser)->
        assert.ok browser.querySelector("html head")
        assert.equal browser.text("html body h1"), "Tag soup"
      "should close tags": (browser)->
        paras = browser.querySelectorAll("body p").toArray().map((e)-> e.textContent.trim())
        assert.deepEqual paras, ["One paragraph", "And another"]


  "adding script using document.write":
    zombie.wants "http://localhost:3003/script/write"
      "should run script": (browser)-> assert.equal browser.document.title, "Script document.write"
  "adding script using appendChild":
    zombie.wants "http://localhost:3003/script/append"
      "should change html": (browser)->
        console.log browser.html()
      "should run script": (browser)-> assert.equal browser.document.title, "Script appendChild"

).export(module)
