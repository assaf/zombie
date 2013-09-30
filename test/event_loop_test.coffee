{ assert, brains, Browser } = require("./helpers")
Q = require("q")


describe "EventLoop", ->

  browser = null
  before (done)->
    browser = Browser.create()
    brains.ready(done)

  before ->
    brains.get "/eventloop/function", (req, res)-> res.send """
      <html>
        <head><title></title></head>
      </html>
      """

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

      before (done)->
        browser.visit "http://localhost:3003/eventloop/timeout", ->
          browser.window.setTimeout ->
            document.title += " Two"
          , 100
          done()

      it "should not fire any timeout events", ->
        browser.assert.text "title", "One"

    describe "from timeout", ->

      before (done)->
        browser.visit "http://localhost:3003/eventloop/timeout", ->
          browser.window.setTimeout ->
            @setTimeout ->
              @document.title += " Two"
              @setTimeout ->
                @document.title += " Three"
              , 100
            , 100
          , 100
          browser.wait(done)

      it "should fire all timeout events", ->
        browser.assert.text "title", "One Two Three"

    describe "wait for all", ->

      before (done)->
        browser.visit "http://localhost:3003/eventloop/timeout", ->
          browser.window.setTimeout ->
            @document.title += " Two"
          , 100
          browser.window.setTimeout ->
            @document.title += " Three"
          , 200
          browser.wait(250, done)

      it "should fire all timeout events", ->
        browser.assert.text "title", "One Two Three"

    describe "cancel timeout", ->
      before (done)->
        browser.visit "http://localhost:3003/eventloop/timeout", ->
          first = browser.window.setTimeout ->
            @document.title += " Two"
          , 100
          second = browser.window.setTimeout ->
            @document.title += " Three"
          , 200
          setTimeout ->
            browser.window.clearTimeout(second)
          , 100
          browser.wait(300, done)

      it "should fire only uncancelled timeout events", ->
        browser.assert.text "title", "One Two"
      it "should not choke on invalid timers", ->
        assert.doesNotThrow ->
          # clearTimeout should not choke when clearing an invalid timer
          # https://developer.mozilla.org/en/DOM/window.clearTimeout
          browser.window.clearTimeout(undefined)

    describe "outside wait", ->

      before (done)->
        browser.visit("http://localhost:3003/eventloop/function")
          .then ->
            browser.window.setTimeout (-> @document.title += "1"), 100
            browser.window.setTimeout (-> @document.title += "2"), 200
            browser.window.setTimeout (-> @document.title += "3"), 300
            return
          .then ->
            browser.wait(120) # wait long enough to fire no. 1
          .then ->
            browser.wait(120) # wait long enough to fire no. 2
          .then ->
            # wait long enough to fire no. 3, but no events processed
            setTimeout(done, 200)

      it "should not fire", ->
        browser.assert.text "title", "12"

    describe "zero wait", ->
      before (done)->
        browser.visit "http://localhost:3003/eventloop/timeout", ->
          browser.window.setTimeout ->
            @document.title += " Two"
          , 0
          browser.wait(done)

      it "should wait for event to fire", ->
        browser.assert.text "title", "One Two"


  describe "setImmediate", ->
    before ->
      brains.get "/eventloop/immediate", (req, res)-> res.send """
        <html>
          <head><title></title></head>
          <body></body>
        </html>
        """

    describe "with wait", ->
      before (done)->
        browser.visit "http://localhost:3003/eventloop/immediate", ->
          browser.window.setImmediate ->
            @document.title += "."
          browser.wait(done)

      it "should not fire the immediate", ->
        browser.assert.text "title", "."

    describe "clearImmediate", ->
      before (done)->
        browser.visit "http://localhost:3003/eventloop/immediate", ->
          immediate = browser.window.setImmediate ->
            @document.title += "."
          browser.window.clearImmediate immediate
          browser.wait(done)

      it "should not fire any immediates", ->
        browser.assert.text "title", ""


  describe "setInterval", ->
    before ->
      brains.get "/eventloop/interval", (req, res)-> res.send """
        <html>
          <head><title></title></head>
          <body></body>
        </html>
        """

    describe "no wait", ->
      before (done)->
        browser.visit "http://localhost:3003/eventloop/interval", ->
          browser.window.setInterval ->
            @document.title += "."
          , 100
          done()

      it "should not fire any timeout events", ->
        browser.assert.text "title", ""

    describe "wait once", ->
      before (done)->
        browser.visit "http://localhost:3003/eventloop/interval", ->
          browser.window.setInterval ->
            @document.title += "."
          , 100
          browser.wait(150, done)

      it "should fire interval event once", ->
        browser.assert.text "title", "."

    describe "wait long enough", ->
      before (done)->
        browser.visit("http://localhost:3003/eventloop/interval")
          .then ->
            # Fire every 100 ms
            browser.window.setInterval ->
              @document.title += "."
            , 100
            return
          .then ->
            # Only wait for first 3 events
            browser.wait(350)
          .then(done, done)

      it "should fire five interval event", ->
        browser.assert.text "title", "..."

    describe "cancel interval", ->
      before (done)->
        interval = null
        browser.visit("http://localhost:3003/eventloop/interval")
          .then ->
            interval = browser.window.setInterval ->
              @document.title += "."
            , 100
            return
          .then ->
            browser.wait(250)
          .then ->
            browser.window.clearInterval(interval)
            browser.wait(200)
          .then(done, done)

      it "should fire only uncancelled interval events", ->
        browser.assert.text "title", ".."
      it "should not throw an exception with invalid interval", ->
        assert.doesNotThrow ->
          # clearInterval should not choke on invalid interval
          browser.window.clearInterval(undefined)

    describe "outside wait", ->
      before (done)->
        browser.visit("http://localhost:3003/eventloop/function")
          .then ->
            browser.window.setInterval ->
              @document.title += "."
            , 100
          .then ->
            browser.wait(120) # wait long enough to fire no. 1
          .then ->
            browser.wait(120) # wait long enough to fire no. 2
          .then ->
            # wait long enough to fire no. 3, but no events processed
            setTimeout(done, 200)

      it "should not fire", ->

  describe "browser.wait completion", ->
    before (done)->
      browser.visit("http://localhost:3003/eventloop/function")
        .then ->
          browser.window.setInterval ->
            @document.title += "."
          , 100
          return
        .then ->
          return browser.wait (window)->
            return window.document.title == "...."
          , null
        .then(done, done)

    it "should not wait longer than specified", ->
        browser.assert.text "title", "...."


  describe "page load", ->
    before ->
      brains.get "/eventloop/dcl", (req, res)-> res.send """
        <html>
          <head><title></title></head>
          <script>
          window.documentDCL = 0;
          document.addEventListener("DOMContentLoaded", function() {
            ++window.documentDCL;
          });
          window.windowDCL = 0;
          window.addEventListener("DOMContentLoaded", function() {
            ++window.windowDCL;
          });
          </script>
          <div id="foo"></div>
        </html>
        """

    before (done)->
      browser.visit("/eventloop/dcl", done)

    it "should file DOMContentLoaded event on document", ->
      browser.assert.global "documentDCL", 1
    it "should file DOMContentLoaded event on window", ->
      browser.assert.global "windowDCL", 1

  describe "all resources loaded", ->
    before ->
      brains.get "/eventloop/onload", (req, res)-> res.send """
        <html>
          <head><title></title></head>
          <script src="/eventloop/onload.js"></script>
          <div id="foo"></div>
        </html>
        """
      brains.get "/eventloop/onload.js", (req, res)->
        setTimeout ->
          res.send """
            window.documentLoad = 0;
            document.addEventListener("load", function() {
              ++window.documentLoad;
            });
            window.windowLoad = 0;
            window.addEventListener("load", function() {
              ++window.windowLoad;
            });
          """
        , 100

    before (done)->
      browser.visit("/eventloop/onload", done)

    it "should file load event on document", ->
      browser.assert.global "documentLoad", 1
    it "should file load event on window", ->
      browser.assert.global "windowLoad", 1


  after ->
    browser.destroy()
