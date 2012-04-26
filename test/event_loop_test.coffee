{ assert, brains, Browser } = require("./helpers")


describe "EventLoop", ->

  before (done)->
    brains.get "/eventloop/function", (req, res)-> res.send """
      <html>
        <head><title></title></head>
      </html>
      """
    brains.ready done


  describe "setTimeout", ->
    before ->
      brains.get "/eventloop/timeout", (req, res)->
        res.send """
        <html>
          <head><title>One</title></head>
          <body></body>
        </html>
        """

    describe "no wait", ->
      browser = new Browser()

      before (done)->
        browser.visit "http://localhost:3003/eventloop/timeout", ->
          browser.window.setTimeout ->
            @document.title += " Two"
          , 100
          done()

      it "should not fire any timeout events", ->
        assert.equal browser.document.title, "One"

    describe "from timeout", ->
      browser = new Browser()

      before (done)->
        browser.visit "http://localhost:3003/eventloop/timeout", ->
          browser.window.setTimeout ->
            browser.window.setTimeout ->
              @document.title += " Two"
              browser.window.setTimeout ->
                @document.title += " Three"
              , 100
            , 100
          , 100
          browser.wait done

      it "should not fire any timeout events", ->
        assert.equal browser.document.title, "One Two Three"

    describe "wait for all", ->
      browser = new Browser()

      before (done)->
        browser.visit "http://localhost:3003/eventloop/timeout", ->
          browser.window.setTimeout ->
            @document.title += " Two"
          , 100
          browser.window.setTimeout ->
            @document.title += " Three"
          , 200
          browser.wait 250, done

      it "should fire all timeout events", ->
        assert.equal browser.document.title, "One Two Three"

    describe "cancel timeout", ->
      browser = new Browser()

      before (done)->
        browser.visit "http://localhost:3003/eventloop/timeout", ->
          first = browser.window.setTimeout ->
            @document.title += " Two"
          , 100
          second = browser.window.setTimeout ->
            @document.title += " Three"
          , 200
          setTimeout ->
            browser.window.clearTimeout second
          , 100
          browser.wait 300, done

      it "should fire only uncancelled timeout events", ->
        assert.equal browser.document.title, "One Two"
      it "should not choke on invalid timers", ->
        assert.doesNotThrow ->
          # clearTimeout should not choke when clearing an invalid timer
          # https://developer.mozilla.org/en/DOM/window.clearTimeout
          browser.window.clearTimeout undefined

    describe "outside wait", ->
      browser = new Browser()

      before (done)->
        browser.visit "http://localhost:3003/eventloop/function", ->
          browser.window.setTimeout (-> @document.title += "1"), 100
          browser.window.setTimeout (-> @document.title += "2"), 200
          browser.window.setTimeout (-> @document.title += "3"), 300
          browser.wait 100, ->
            setTimeout ->
              browser.wait 100, done
            , 300

      it "should not fire", ->
        assert.equal browser.document.title, "12"


  describe "setInterval", ->
    before ->
      brains.get "/eventloop/interval", (req, res)-> res.send """
        <html>
          <head><title></title></head>
          <body></body>
        </html>
        """

    describe "no wait", ->
      browser = new Browser()

      before (done)->
        browser.visit "http://localhost:3003/eventloop/interval", ->
          browser.window.setInterval ->
            @document.title += "."
          , 100
          done()

      it "should not fire any timeout events", ->
        assert.equal browser.document.title, ""

    describe "wait once", ->
      browser = new Browser()

      before (done)->
        browser.visit "http://localhost:3003/eventloop/interval", ->
          browser.window.setInterval ->
            @document.title += "."
          , 100
          browser.wait 150, done

      it "should fire interval event once", ->
        assert.equal browser.document.title, "."

    describe "wait long enough", ->
      browser = new Browser()

      before (done)->
        browser.visit "http://localhost:3003/eventloop/interval", ->
          browser.window.setInterval ->
            @document.title += "."
          , 100
          browser.wait 350, done

      it "should fire five interval event", ->
        assert.equal browser.document.title, "..."

    describe "cancel interval", ->
      browser = new Browser()

      before (done)->
        browser.visit "http://localhost:3003/eventloop/interval", ->
          interval = browser.window.setInterval ->
            @document.title += "."
          , 100
          browser.wait 250, ->
            browser.window.clearInterval interval
            browser.wait 200, done

      it "should fire only uncancelled interval events", ->
        assert.equal browser.document.title, ".."
      it "should not throw an exception with invalid interval", ->
        assert.doesNotThrow ->
          # clearInterval should not choke on invalid interval
          browser.window.clearInterval undefined

    describe "outside wait", ->
      browser = new Browser()

      before (done)->
        browser.visit "http://localhost:3003/eventloop/function", ->
          browser.window.setInterval (-> @document.title += "."), 100
          browser.wait 120, ->
            setTimeout ->
              browser.wait 120, done
            , 300

      it "should not fire", ->
        assert.equal browser.document.title, ".."


  describe "browser.wait function", ->
    browser = new Browser()

    before (done)->
      browser.visit "http://localhost:3003/eventloop/function", ->
        browser.window.setInterval (-> @document.title += "."), 100
        gotFourDots = (window)->
          return window.document.title == "...."
        browser.wait gotFourDots, done

    it "should not wait longer than specified", ->
      assert.equal browser.document.title, "...."

