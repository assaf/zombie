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
      <div id="main"></div>
      <a href="/dead">Kill</a>
      <form>
        <label>Name <input type="text" name="name" id="field-name"></label>
        <label for="field-email">Email</label>
        <input type="text" name="email" id="field-email"></label>
        <textarea name="likes" id="field-likes"></textarea>
        <input type="password" name="password" id="field-password">
      </form>
      <div class="now">Walking Aimlessly</div>
    </body>
  </html>
  """
brains.get "/app.js", (req, res)-> res.send """
  Sammy("#main", function(app) {
    app.get("#/", function(context) {
      context.swap("The Living");
    });
    app.get("#/dead", function(context) {
      context.swap("The Living Dead");
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


vows.describe("Browser").addBatch(
  "open page":
    zombie.wants "http://localhost:3003/scripted"
      "should create HTML document": (browser)-> assert.instanceOf browser.document, jsdom.dom.level3.html.HTMLDocument
      "should load document from server": (browser)-> assert.match browser.html(), /<body>Hello World<\/body>/
      "should load external scripts": (browser)->
        assert.ok jQuery = browser.window.jQuery, "window.jQuery not available"
        assert.typeOf jQuery.ajax, "function"
      "should run jQuery.onready": (browser)-> assert.equal browser.document.title, "Awesome"

  "run app":
    zombie.wants "http://localhost:3003/living"
      "should execute route": (browser)-> assert.equal browser.text("#main"), "The Living"
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
        "should combine multiple elements": (browser)-> assert.equal browser.text("form label"), "Name Email"
      "query html":
        topic: (browser)-> browser
        "should query from document": (browser)-> assert.equal browser.html(".now"), "<div class=\"now\">Walking Aimlessly</div>"
        "should query from context": (browser)-> assert.equal browser.html(".now", browser.body), "Walking Aimlessly"
        "should query from context": (browser)-> assert.equal browser.html(".now", browser.querySelector("#main")), ""
        "should combine multiple elements": (browser)-> assert.equal browser.html("#main, a"), "<div id=\"main\">The Living</div><a href=\"/dead\">Kill</a>"

  "click link":
    zombie.wants "http://localhost:3003/living"
      topic: (browser)->
        browser.clickLink "Kill", @callback
      "should change location": (browser)-> assert.equal browser.location, "http://localhost:3003/dead"
      "should run all events": (browser)-> assert.equal browser.document.title, "The Dead"

).export(module)
