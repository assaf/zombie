require("./helpers")
{ vows: vows, assert: assert, zombie: zombie, brains: brains } = require("vows")


brains.get "/timeout", (req, res)-> res.send """
  <html>
    <head><title>One</title></head>
    <body>
      <script>
        window.second = window.setTimeout(function() { document.title = document.title + " Three" }, 5000);
        window.first = window.setTimeout(function() { document.title = document.title + " Two" }, 1000);
      </script>
    </body>
  </html>
  """

brains.get "/interval", (req, res)-> res.send """
  <html>
    <head><title></title></head>
    <body>
      <script>
        window.interval = window.setInterval(function() { document.title = document.title + "." }, 1000);
      </script>
    </body>
  </html>
  """


vows.describe("EventLoop").addBatch({
  "setTimeout":
    "no wait":
      zombie.wants "http://localhost:3003/timeout"
        ready: (browser)-> @callback null, browser
        "should not fire any timeout events": (browser)-> assert.equal browser.document.title, "One"
        "should not change clock": (browser) -> assert.equal browser.clock, 0
    "wait for all":
      zombie.wants "http://localhost:3003/timeout"
        ready: (browser)-> browser.wait @callback
        "should fire all timeout events": (browser)-> assert.equal browser.document.title, "One Two Three"
        "should move clock forward": (browser) -> assert.equal browser.clock, 5000
    "cancel timeout":
      zombie.wants "http://localhost:3003/timeout"
        ready: (browser)->
          terminate = ->
            browser.window.clearTimeout browser.window.second
            false
          browser.wait terminate, @callback
        "should fire only uncancelled timeout events": (browser)->
          assert.equal browser.document.title, "One Two"
          assert.equal browser.clock, 1000

  "setInterval":
    "no wait":
      zombie.wants "http://localhost:3003/interval"
        ready: (browser)-> @callback null, browser
        "should not fire any timeout events": (browser)-> assert.equal browser.document.title, ""
        "should not change clock": (browser) -> assert.equal browser.clock, 0
    "wait once":
      zombie.wants "http://localhost:3003/interval"
        ready: (browser)-> browser.wait @callback
        "should fire interval event once": (browser)->
          assert.equal browser.document.title, "."
          assert.equal browser.clock, 1000
    "wait three times":
      zombie.wants "http://localhost:3003/interval"
        ready: (browser)->
          browser.wait 5, =>
            browser.wait =>
              browser.wait @callback
        "should fire five interval event": (browser)-> assert.equal browser.document.title, "..."
        "should move clock forward": (browser) -> assert.equal browser.clock, 3000
    "cancel interval":
      zombie.wants "http://localhost:3003/interval"
        ready: (browser)->
          browser.wait  =>
            browser.window.clearInterval browser.window.interval
            browser.wait @callback
        "should fire only uncancelled interval events": (browser)->
          assert.equal browser.document.title, "."
          assert.equal browser.clock, 1000
}).export(module);
