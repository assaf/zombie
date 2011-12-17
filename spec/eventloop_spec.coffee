{ Vows, assert, brains, Browser } = require("./helpers")


Vows.describe("EventLoop").addBatch(

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
      Browser.wants "http://localhost:3003/eventloop/timeout"
        topic: (browser)->
          browser.window.setTimeout ->
            @document.title += " Two"
          , 100
          @callback null, browser
        "should not fire any timeout events": (browser)->
          assert.equal browser.document.title, "One"

    "wait for all":
      Browser.wants "http://localhost:3003/eventloop/timeout"
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
      Browser.wants "http://localhost:3003/eventloop/timeout"
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
      Browser.wants "http://localhost:3003/eventloop/interval"
        topic: (browser)->
          browser.window.setInterval ->
            @document.title += "."
          , 100
          @callback null, browser
        "should not fire any timeout events": (browser)->
          assert.equal browser.document.title, ""

    "wait once":
      Browser.wants "http://localhost:3003/eventloop/interval"
        topic: (browser)->
          browser.window.setInterval ->
            @document.title += "."
          , 100
          browser.wait 150, @callback
        "should fire interval event once": (browser)->
          assert.equal browser.document.title, "."

    "wait long enough":
      Browser.wants "http://localhost:3003/eventloop/interval"
        topic: (browser)->
          browser.window.setInterval ->
            @document.title += "."
          , 100
          browser.wait 350, @callback
        "should fire five interval event": (browser)->
          assert.equal browser.document.title, "..."

    "cancel interval":
      Browser.wants "http://localhost:3003/eventloop/interval"
        topic: (browser)->
          interval = browser.window.setInterval ->
            @document.title += "."
          , 100
          browser.wait 250, =>
            browser.window.clearInterval interval
            browser.wait 200, @callback
        "should fire only uncancelled interval events": (browser)->
          assert.equal browser.document.title, ".."


  "browser.wait function":
    topic: ->
      brains.get "/eventloop/function", (req, res)-> res.send """
        <html>
          <head><title></title></head>
        </html>
        """
      browser = new Browser
      browser.wants "http://localhost:3003/eventloop/function", =>
        browser.window.setInterval (-> @document.title += "."), 100
        gotFourDots = (window)->
          return window.document.title == "...."
        browser.wait gotFourDots, @callback
    "should not wait longer than specified": (browser)->
      assert.equal browser.document.title, "...."


).export(module)
