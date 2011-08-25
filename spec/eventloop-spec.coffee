require("./helpers")
{ vows: vows, assert: assert, zombie: zombie, brains: brains } = require("vows")



vows.describe("EventLoop").addBatch(
  "setTimeout":
    topic: ->
      brains.get "/eventloop/timeout", (req, res)-> res.send """
        <html>
          <head><title>One</title></head>
          <body></body>
        </html>
        """
      @callback null
    "no wait":
      zombie.wants "http://localhost:3003/eventloop/timeout"
        topic: (browser)->
          browser.clock = 0
          browser.window.setTimeout (-> @document.title += " Two"), 1000
          @callback null, browser
        "should not fire any timeout events": (browser)-> assert.equal browser.document.title, "One"
        "should not change clock": (browser) -> assert.equal browser.clock, 0
    "wait for all":
      zombie.wants "http://localhost:3003/eventloop/timeout"
        topic: (browser)->
          browser.clock = 0
          browser.window.setTimeout (-> @document.title += " Two"), 3000
          browser.window.setTimeout (-> @document.title += " Three"), 5000
          browser.wait @callback
        "should fire all timeout events": (browser)-> assert.equal browser.document.title, "One Two Three"
        "should move clock forward": (browser) -> assert.equal browser.clock, 5000
    "cancel timeout":
      zombie.wants "http://localhost:3003/eventloop/timeout"
        topic: (browser)->
          browser.clock = 0
          first = browser.window.setTimeout (-> @document.title += " Two"), 3000
          second = browser.window.setTimeout (-> @document.title += " Three"), 5000
          terminate = ->
            browser.window.clearTimeout second
            false
          browser.wait terminate, @callback
        "should fire only uncancelled timeout events": (browser)->
          assert.equal browser.document.title, "One Two"
          assert.equal browser.clock, 3000

  "setInterval":
    topic: ->
      brains.get "/eventloop/interval", (req, res)-> res.send """
        <html>
          <head><title></title></head>
          <body></body>
        </html>
        """
      @callback null
    "no wait":
      zombie.wants "http://localhost:3003/eventloop/interval"
        topic: (browser)->
          browser.clock = 0
          browser.window.setInterval (-> @document.title += "."), 1000
          @callback null, browser
        "should not fire any timeout events": (browser)-> assert.equal browser.document.title, ""
        "should not change clock": (browser) -> assert.equal browser.clock, 0
    "wait once":
      zombie.wants "http://localhost:3003/eventloop/interval"
        topic: (browser)->
          browser.clock = 0
          browser.window.setInterval (-> @document.title += "."), 1000
          browser.wait @callback
        "should fire interval event once": (browser)->
          assert.equal browser.document.title, "."
          assert.equal browser.clock, 1000
    "wait three times":
      zombie.wants "http://localhost:3003/eventloop/interval"
        topic: (browser)->
          browser.clock = 0
          browser.window.setInterval (-> @document.title += "."), 1000
          browser.wait 5, =>
            browser.wait =>
              browser.wait @callback
        "should fire five interval event": (browser)-> assert.equal browser.document.title, "..."
        "should move clock forward": (browser) -> assert.equal browser.clock, 3000
    "cancel interval":
      zombie.wants "http://localhost:3003/eventloop/interval"
        topic: (browser)->
          browser.clock = 0
          interval = browser.window.setInterval (-> @document.title += "."), 1000
          browser.wait  =>
            browser.window.clearInterval interval
            browser.wait @callback
        "should fire only uncancelled interval events": (browser)->
          assert.equal browser.document.title, "."
          assert.equal browser.clock, 1000
).export(module)
