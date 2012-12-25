{ assert, brains, Browser } = require("./helpers")


describe "EventSource", ->

  browser = null
  before (done)->
    browser = Browser.create()
    brains.ready(done)

  before ->
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

    brains.get "/stream", (req, res)->
      res.writeHead 200,
        "Content-Type":   "text/event-stream; charset=utf-8"
        "Cache-Control":  "no-cache"
        "Connection":     "keep-alive"
      res.write "event: test\nid: 1\ndata: first\n\n"
      setTimeout ->
        res.write "event: test\nid: 2\ndata: second\n\n"
        res.end()
      , 100

  before (done)->
    browser.visit("http://localhost:3003/streaming")
    browser.wait (window)->
      return window.events && window.events.length == 2
    , =>
      @events = browser.evaluate("window.events")
      done()

  it "should stream to browser", ->
    assert.deepEqual @events, ["first", "second"]

  after ->
    # TODO: this blows up
    # browser.destroy()
