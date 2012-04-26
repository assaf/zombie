{ assert, brains, Browser } = require("./helpers")
Express = require("express")
WebSocket = require("ws")


describe "WebSockets", ->

  before ->
    ws_server = new WebSocket.Server(server: brains)
    ws_server.on "connection", (client)->
      client.send "Hello"


  describe "socket", ->
    browser = new Browser()

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
              ws = new WebSocket('ws://localhost:3003');
              $('#ws-url').text(ws.url);
            });
          </script>
        </html>
        """
      brains.ready ->
        browser.visit "http://localhost:3003/websockets/creating", done

    it "should be possible", ->
      assert.equal browser.text("#ws-url"), "ws://localhost:3003"


  describe "connecting", ->
    browser = new Browser()

    before (done)->
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
      browser.onalert ->
        done()
      browser.visit "http://localhost:3003/websockets/connecting"

    it "should raise an event", ->
      assert browser.prompted("open")


  describe "message", ->
    browser = new Browser()

    before (done)->
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
      browser.onalert ->
        done()
      browser.visit "http://localhost:3003/websockets/message"

    it "should raise an event with correct data", ->
      assert browser.prompted("Hello")


  describe "closing", ->
    browser = new Browser()

    before (done)->
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
      browser = new Browser()
      browser.onalert ->
        done()
      browser.visit "http://localhost:3003/websockets/closing"

    it "should raise an event", ->
      assert browser.prompted("close")

