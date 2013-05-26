{ assert, brains, Browser } = require("./helpers")
WebSocket = require("ws")


describe "WebSockets", ->

  browser = null

  before (done)->
    browser = Browser.create()
    brains.ready(done)

  before (done)->
    ws_server = new WebSocket.Server(port: 3004, done)
    ws_server.on "connection", (client)->
      client.send("Hello")

  describe "socket", ->
    before ->
      brains.get "/websockets", (req, res)->
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
              ws = new WebSocket("ws://localhost:3004");
              $('#ws-url').text(ws.url);
              ws.onopen = function() {
                alert('open');
              };
              ws.onmessage = function(message) {
                alert(message.data);
              };
              ws.onclose = function() {
                alert('close');
              };
              setTimeout(function() {
                ws.close();
              }, 100);
            });
          </script>
        </html>
        """

    prompts = []
    before (done)->
      browser.visit("/websockets")
      browser.on "alert", (message)->
        prompts.push(message)
        if message == "close"
          done()

    it "should be possible", ->
      browser.assert.text "#ws-url", "ws://localhost:3004"
    it "should raise open event after connecting", ->
      assert.equal prompts[0], "open"
    it "should raise message event for each message", ->
      assert.equal prompts[1], "Hello"
    it "should raise close event when closed", ->
      assert.equal prompts[2], "close"

  after ->
    browser.destroy()
