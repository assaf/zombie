{ Vows, assert, brains, Browser } = require("./helpers")


Vows.describe("Resources").addBatch

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

    "resources":
      topic: ->
          brains.ready =>
            browser = new Browser
            browser.visit "http://localhost:3003/browser/scripted", @callback
      "should exist on the browser": (browser)->
        assert.ok browser.resources
      "should have a length": (browser)->
        assert.equal browser.resources.length, 2
      "should include jquery": (browser)->
        assert.equal browser.resources[1].url, "http://localhost:3003/jquery-1.7.1.js"
      "should include the 'self' url": (browser)->
        assert.equal browser.resources[0].url, "http://localhost:3003/browser/scripted"
      "should have a 'dump' method": (browser)->
        try
          browser.resources.toString()
        catch e
          assert.ok false, "calling dump method throws an error [" + e + "]"


.export(module)
