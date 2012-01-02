{ Vows, assert, brains, Browser } = require("./helpers")


Vows.describe("Compatibility with WebSockets").addBatch(
  "WebSockets":
    topic: ->
      brains.get "/ws", (req, res)->
        res.send """
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
            <span id="ws-url"></span>
          </body>
          <script>
            $(function() {
              ws = new WebSocket('ws://localhost:3003');
              $('#ws-url').text(ws.url);
            });
          </script>
        </html>
        """
      browser = new Browser
      browser.wants "http://localhost:3003/ws", @callback
    "Creating a Websocket":
      topic: (browser)->
        browser.text "#ws-url"
        @callback null, browser
      "should be possible": (browser)->
        assert.equal browser.text("#ws-url"), "ws://localhost:3003"

).export(module)
