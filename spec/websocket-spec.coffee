require "./helpers"
{ vows: vows, assert: assert, Browser: Browser, brains: brains } = require("vows")


vows.describe("Compatibility with WebSockets").addBatch(
  "WebSockets":
    topic: ->
      brains.get "/ws", (req, res)-> res.send """
        <html>
          <head>
            <title>jQuery</title>
            <script src="/jquery.js"></script>
          </head>
          <body>
            <select>
              <option>None</option>
              <option value="1">One</option>
            </select>

            <span id="ws"></span>

            <a href="#post">Post</a>

            <div id="response"></div>
          </body>

          <script>
            $(function() {

            ws = new WebSocket('ws://localhost/some/url');
            $('#ws').text(ws.url);

            });
          </script>
        </html>
        """
      browser = new Browser
      browser.wants "http://localhost:3003/ws", @callback
    "Creating a Websocket":
      topic: (browser)->
        browser.text "#ws"
        @callback null, browser
      "should be possible": (browser)-> assert.equal browser.text("#ws"), "ws://localhost/some/url"

).export(module)
