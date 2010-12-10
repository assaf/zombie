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
    <body></body>
  </html>
  """
brains.get "/sammy.js", (req, res)->
  fs.readFile "#{__dirname}/../data/sammy.js", (err, data)-> res.send data
brains.get "/app.js", (req, res)-> res.send """
  Sammy("body", function(app) {
    app.get("#/", function(context) {
      context.swap("The Living");
    });
    app.get("#/dead", function(context) {
      context.swap("The Living Dead");
    });
  });
  $(function() { Sammy("body").run("#/") });
  """


vows.describe("Browser").addBatch({
  "open page":
    zombie.wants "http://localhost:3003/scripted"
      "should create HTML document": (window)-> assert.instanceOf window.document, jsdom.dom.level3.html.HTMLDocument
      "should load document from server": (window)-> assert.match window.document.outerHTML, /<body>Hello World<\/body>/
      "should load external scripts": (window)->
        assert.ok jQuery = window.jQuery, "window.jQuery not available"
        assert.typeOf jQuery.ajax, "function"
      "should run jQuery.onready": (window)-> assert.equal window.document.title, "Awesome"

  "run sammy app":
    zombie.wants "http://localhost:3003/living"
      #ready: (err, window)-> window.wait @callback
      "should execute route": (window)-> assert.equal window.$("body").html(), "The Living"
      "should change location": (window)-> assert.equal window.location.href, "http://localhost:3003/living#/"
      "move around":
        topic: (window)->
          window.location = "#/dead"
          window.wait @callback
        "should execute route": (window)-> assert.equal window.$("body").html(), "The Living Dead"
        "should change location": (window)-> assert.equal window.location.href, "http://localhost:3003/living#/dead"
}).export(module);
