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

    "from timeout":
      Browser.wants "http://localhost:3003/eventloop/timeout"
        topic: (browser)->
          browser.window.setTimeout ->
            browser.window.setTimeout ->
              @document.title += " Two"
              browser.window.setTimeout ->
                @document.title += " Three"
              , 100
            , 100
          , 100
          browser.wait @callback
        "should not fire any timeout events": (browser)->
          assert.equal browser.document.title, "One Two Three"

    "wait for all":
      Browser.wants "http://localhost:3003/eventloop/timeout"
        topic: (browser)->
          browser.window.setTimeout ->
            @document.title += " Two"
          , 100
          browser.window.setTimeout ->
            @document.title += " Three"
          , 200
          browser.wait 250, @callback
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
        "should not choke on invalid timers": (browser)->
          assert.doesNotThrow ->
            # clearTimeout should not choke when clearing an invalid timer
            # https://developer.mozilla.org/en/DOM/window.clearTimeout
            browser.window.clearTimeout undefined

    "outside wait":
      Browser.wants "http://localhost:3003/eventloop/timeout"
        topic: (browser)->
          browser.wants "http://localhost:3003/eventloop/function", =>
            browser.window.setTimeout (-> @document.title += "1"), 100
            browser.window.setTimeout (-> @document.title += "2"), 200
            browser.window.setTimeout (-> @document.title += "3"), 300
            browser.wait 100, =>
              setTimeout =>
                browser.wait 100, @callback
              , 300
        "should not fire": (browser)->
          assert.equal browser.document.title, "12"


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
        "should not throw an exception with invalid interval": (browser)->
          assert.doesNotThrow ->
            # clearInterval should not choke on invalid interval
            browser.window.clearInterval undefined

    "outside wait":
      Browser.wants "http://localhost:3003/eventloop/interval"
        topic: (browser)->
          browser.wants "http://localhost:3003/eventloop/function", =>
            browser.window.setInterval (-> @document.title += "."), 100
            browser.wait 100, =>
              setTimeout =>
                browser.wait 100, @callback
              , 300
        "should not fire": (browser)->
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
