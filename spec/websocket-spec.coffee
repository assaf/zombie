require "./helpers"
{ vows: vows, assert: assert, zombie: zombie, brains: brains } = require("vows")
jsdom = require("jsdom")

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

brains.post "/echo", (req, res)->
  lines = for key, value of req.body
    key + "=" + value

  res.send lines.join("\n")

vows.describe("Compatibility with WebSockets").addBatch(
  "WebSockets":
    zombie.wants "http://localhost:3003/ws"
      "Creating a Websocket":
        topic: (browser)->
          browser.text "#ws"
          @callback null, browser
        "should be possible": (browser)-> assert.equal browser.text("#ws"), "ws://localhost/some/url"


).export(module)
