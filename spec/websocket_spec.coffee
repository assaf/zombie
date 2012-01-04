{ Vows, assert, brains, Browser } = require("./helpers")


Vows.describe("WebSockets").addBatch

  "creating":
    topic: ->
      brains.get "/websockets/creating", (req, res)->
        res.send """
        <html>
          <head>
            <script src="/jquery.js"></script>
          </head>
          <body>
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
      browser.wants "http://localhost:3003/websockets/creating", @callback
    "should be possible": (browser)->
      assert.equal browser.text("#ws-url"), "ws://localhost:3003"

  "connecting":
    topic: ->
      brains.get "/websockets/connecting", (req, res)->
        res.send """
        <html>
          <head></head>
          <body></body>
          <script>
            ws = new WebSocket('ws://localhost:3003');
            ws.onopen = function() {
              alert('open');
            };
          </script>
        </html>
        """
      done = @callback
      browser = new Browser()
      browser.onalert (message)->
        done null, browser
      browser.wants "http://localhost:3003/websockets/connecting"
    "should raise an event": (browser)->
      assert.ok browser.prompted("open")

  "message":
    topic: ->
      brains.get "/websockets/message", (req, res)->
        res.send """
        <html>
          <head></head>
          <body></body>
          <script>
            ws = new WebSocket('ws://localhost:3003');
            ws.onmessage = function(message) {
              alert(message.data);
            };
          </script>
        </html>
        """
      done = @callback
      browser = new Browser()
      browser.onalert (message)->
        done null, browser
      browser.wants "http://localhost:3003/websockets/message"
    "should raise an event with correct data": (browser)->
      assert.ok browser.prompted("Hello")

  "closing":
    topic: ->
      brains.get "/websockets/closing", (req, res)->
        res.send """
        <html>
          <head></head>
          <body></body>
          <script>
            ws = new WebSocket('ws://localhost:3003');
            ws.onclose = function() {
              alert('close');
            };
            ws.close();
          </script>
        </html>
        """
      done = @callback
      browser = new Browser()
      browser.onalert (message)->
        done null, browser
      browser.wants "http://localhost:3003/websockets/closing"
    "should raise an event": (browser)->
      assert.ok browser.prompted("close")


.export(module)
