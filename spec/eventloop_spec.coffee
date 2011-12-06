{ vows: vows, assert: assert, brains: brains, Zombie: Zombie } = require("./helpers")


vows.describe("EventLoop").addBatch(

  "setTimeout":
    topic: ->
      brains.get "/eventloop/timeout", (req, res)->
        res.send """
        <html>
          <head><title>One</title></head>
          <body></body>
        </html>
        """
      @callback null

    "no wait":
      Zombie.wants "http://localhost:3003/eventloop/timeout"
        topic: (browser)->
          browser.window.setTimeout ->
            @document.title += " Two"
          , 100
          @callback null, browser
        "should not fire any timeout events": (browser)->
          assert.equal browser.document.title, "One"

    "wait for all":
      Zombie.wants "http://localhost:3003/eventloop/timeout"
        topic: (browser)->
          browser.window.setTimeout ->
            @document.title += " Two"
          , 100
          browser.window.setTimeout ->
            @document.title += " Three"
          , 200
          browser.wait 200, @callback
        "should fire all timeout events": (browser)->
          assert.equal browser.document.title, "One Two Three"

    "cancel timeout":
      Zombie.wants "http://localhost:3003/eventloop/timeout"
        topic: (browser)->
          first = browser.window.setTimeout ->
            @document.title += " Two"
          , 100
          second = browser.window.setTimeout ->
            @document.title += " Three"
          , 200
          setTimeout ->
            browser.window.clearTimeout second
          , 100
          browser.wait 300, @callback
        "should fire only uncancelled timeout events": (browser)->
          assert.equal browser.document.title, "One Two"


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
      Zombie.wants "http://localhost:3003/eventloop/interval"
        topic: (browser)->
          browser.window.setInterval ->
            @document.title += "."
          , 100
          @callback null, browser
        "should not fire any timeout events": (browser)->
          assert.equal browser.document.title, ""

    "wait once":
      Zombie.wants "http://localhost:3003/eventloop/interval"
        topic: (browser)->
          browser.window.setInterval ->
            @document.title += "."
          , 100
          browser.wait 150, @callback
        "should fire interval event once": (browser)->
          assert.equal browser.document.title, "."

    "wait long enough":
      Zombie.wants "http://localhost:3003/eventloop/interval"
        topic: (browser)->
          browser.window.setInterval ->
            @document.title += "."
          , 100
          browser.wait 350, @callback
        "should fire five interval event": (browser)->
          assert.equal browser.document.title, "..."

    "cancel interval":
      Zombie.wants "http://localhost:3003/eventloop/interval"
        topic: (browser)->
          interval = browser.window.setInterval ->
            @document.title += "."
          , 100
          browser.wait 150, =>
            browser.window.clearInterval interval
            browser.wait 200, @callback
        "should fire only uncancelled interval events": (browser)->
          assert.equal browser.document.title, "."

).export(module)
