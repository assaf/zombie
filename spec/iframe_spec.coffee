{ Vows, assert, brains, Browser } = require("./helpers")

Vows.describe("IFrame").addBatch

  "iframes":
    topic: ->
      brains.get "/iframe", (req, res)->
        res.send """
        <html>
          <head>
            <script src="/jquery.js"></script>
          </head>
          <body>
            <iframe src="/static" />
          </body>
        </html>
        """
      brains.get "/static", (req, res)->
        res.send """
        <html>
          <head>
            <title>Whatever</title>
          </head>
          <body>Hello World</body>
        </html>
        """
      browser = new Browser
      browser.wants "http://localhost:3003/iframe", =>
        iframe = browser.querySelector("iframe").window
        @callback browser, iframe

    "should load iframe document": (browser, iframe)->
      assert.equal "Whatever", iframe.document.title
      assert.match iframe.document.querySelector("body").innerHTML, /Hello World/
      assert.equal iframe.location, "http://localhost:3003/static"
    "should reference parent window from iframe": (browser, iframe)->
      assert.equal iframe.parent, browser.window.top
    "should not alter the parent": (browser, iframe)->
      assert.equal "http://localhost:3003/iframe", browser.window.location


.export(module)
