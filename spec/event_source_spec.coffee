{ Vows, assert, brains, Browser } = require("./helpers")


Vows.describe("EventSource").addBatch(

  "sse":
    topic: ->
      brains.get "/stream", (req, res)->
        res.writeHead 200,
          "Content-Type":   "text/event-stream; charset=utf-8"
          "Cache-Control":  "no-cache"
          "Connection":     "keep-alive"
        res.write "event: test\nid: 1\ndata: first\n\n"
        setTimeout ->
          res.write "event: test\nid: 2\ndata: second\n\n"
          res.end()
        , 10

      brains.get "/streaming", (req, res)->
        res.send """
        <html>
          <head>
            <script>
              var source = new EventSource("/stream");
              window.events = [];
              source.addEventListener("test", function(event) {
                window.events.push(event.data)
              });
            </script>
          </head>
        </html>
        """

      brains.ready =>
        browser = new Browser
        browser.visit "http://localhost:3003/streaming"
        completed = (window)->
          return window.events && window.events.length == 2
        browser.wait completed, =>
            @callback null, browser.evaluate("window.events")

    "should stream to browse": (events)->
      assert.deepEqual events, ["first", "second"]


).export(module)
