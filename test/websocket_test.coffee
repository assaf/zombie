{ brains, Browser } = require("./helpers")
WebSocket = require("ws")


describe "WebSockets", ->

  before (done)->
    ws_server = new WebSocket.Server(port: 3004, done)
    ws_server.on "connection", (client)->
      client.send "Hello"


  describe "socket", ->
    before (done)->
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
              ws = new WebSocket("ws://localhost:3004");
              $('#ws-url').text(ws.url);
            });
          </script>
        </html>
        """
      brains.ready done

    before (done)->
      @browser = new Browser()
      @browser.visit "/websockets/creating", done

    it "should be possible", ->
      @browser.assert.text "#ws-url", "ws://localhost:3004"


  describe "connecting", ->
    before (done)->
      brains.get "/websockets/connecting", (req, res)->
        res.send """
        <html>
          <head></head>
          <body></body>
          <script>
            ws = new WebSocket("ws://localhost:3004");
            ws.onopen = function() {
              alert('open');
            };
          </script>
        </html>
        """
      brains.ready done

    before (done)->
      @browser = new Browser()
      @browser.visit "/websockets/connecting"
      @browser.onalert ->
        done()

    it "should raise an event", ->
     @browser.assert.prompted "open"


  describe "message", ->
    before (done)->
      brains.get "/websockets/message", (req, res)->
        res.send """
        <html>
          <head></head>
          <body></body>
          <script>
            ws = new WebSocket("ws://localhost:3004/");
            ws.onmessage = function(message) {
              alert(message.data);
            };
          </script>
        </html>
        """
      brains.ready done

    before (done)->
      @browser = new Browser()
      @browser.visit "/websockets/message"
      @browser.onalert ->
        done()

    it "should raise an event with correct data", ->
      @browser.assert.prompted "Hello"


  describe "closing", ->
    before (done)->
      brains.get "/websockets/closing", (req, res)->
        res.send """
        <html>
          <head></head>
          <body></body>
          <script>
            ws = new WebSocket("ws://localhost:3004");
            ws.onclose = function() {
              alert('close');
            };
            ws.close();
          </script>
        </html>
        """
      brains.ready done

    before (done)->
      @browser = new Browser()
      @browser.visit "/websockets/closing"
      @browser.onalert ->
        done()

    it "should raise an event", ->
      @browser.assert.prompted "close"

