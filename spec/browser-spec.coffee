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
    </body>
  </html>
  """
brains.get "/sammy.js", (req, res)->
  fs.readFile "#{__dirname}/../data/sammy.js", (err, data)-> res.send data
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

brains.get "/dead", (req, res)->
  console.log "requested the dead"
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


vows.describe("Browser").addBatch({
  "open page":
    zombie.wants "http://localhost:3003/scripted"
      "should create HTML document": (browser)-> assert.instanceOf browser.document, jsdom.dom.level3.html.HTMLDocument
      "should load document from server": (browser)-> assert.match browser.html, /<body>Hello World<\/body>/
      "should load external scripts": (browser)->
        assert.ok jQuery = browser.window.jQuery, "window.jQuery not available"
        assert.typeOf jQuery.ajax, "function"
      "should run jQuery.onready": (browser)-> assert.equal browser.document.title, "Awesome"

  "run app":
    zombie.wants "http://localhost:3003/living"
      "should execute route": (browser)-> assert.equal browser.select("#main")[0].innerHTML, "The Living"
      "should change location": (browser)-> assert.equal browser.location, "http://localhost:3003/living#/"
      "move around":
        topic: (browser)->
          browser.location = "#/dead"
          browser.wait @callback
        "should execute route": (browser)-> assert.equal browser.select("#main")[0].innerHTML, "The Living Dead"
        "should change location": (browser)-> assert.equal browser.location, "http://localhost:3003/living#/dead"

  "click link":
    zombie.wants "http://localhost:3003/living"
      ready: (browser)->
        browser.clickLink "Kill", @callback
      "should change location": (browser)-> assert.equal browser.location, "http://localhost:3003/dead"
      "should run all events": (browser)-> assert.equal browser.document.title, "The Dead"
}).export(module);
