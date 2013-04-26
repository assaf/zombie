{ assert, brains, Browser } = require("./helpers")
HTML = require("jsdom").dom.level3.html


describe "Browser events", ->
  events =
    console:  []
    log:      []
    resource: []
  browser = null
  before (done)->
    browser = Browser.create()
    brains.ready(done)

  describe "sending output to console", ->
    before ->
      browser.on "console", (level, message)->
        events.console.push(level: level, message: message)
      browser.console.log("Logging", "message")
      browser.console.error("Some", new Error("error"))

    it "should receive console events with the log level", ->
      assert.deepEqual events.console[0].level, "log"
      assert.deepEqual events.console[1].level, "error"

    it "should receive console events with the message", ->
      assert.deepEqual events.console[0].message, "Logging message"
      assert.deepEqual events.console[1].message, "Some [Error: error]"


  describe "logging a message", ->
    before ->
      # Zombie log
      browser.on "log", (message)->
        events.log.push(message)
      browser.log("Zombie", "log")
      browser.log("Zombie", new Error("error"))

    it "should receive log events", ->
      assert.equal events.log[0], "Zombie log"
      assert.equal events.log[1], "Zombie [Error: error]"


  describe "requesting a resource", ->
    before (done)->
      brains.get "/browser-events/resource", (req, res)->
        res.redirect "/browser-events/redirected"
      brains.get "/browser-events/redirected", (req, res)->
        res.send "<html>Very well then</html>"

      browser.on "request", (request)->
        events.resource.push([request])
      browser.on "redirect", (request, response)->
        events.resource.push([request, response])
      browser.on "response", (request, response)->
        events.resource.push([request, response])

      browser.visit "/browser-events/resource", done

    it "should receive resource requests", ->
      [request] = events.resource[0]
      assert.equal request.url, "http://localhost:3003/browser-events/resource"

    it "should receive resource redirects", ->
      [request, response] = events.resource[1]
      assert.equal request.url, "http://localhost:3003/browser-events/resource"
      assert.equal response.statusCode, 302
      assert.equal response.url, "http://localhost:3003/browser-events/redirected"

    it "should receive resource responses", ->
      [request, response] = events.resource[2]
      assert.equal request.url, "http://localhost:3003/browser-events/resource"
      assert.equal response.statusCode, 200
      assert.equal response.redirects, 1


  describe "opening a window", ->
    before ->
      browser.on "opened", (window)->
        events.open = window
      browser.on "active", (window)->
        events.active = window
      browser.open name: "open-test"

    it "should receive opened event", ->
      assert.equal events.open.name, "open-test"

    it "should receive active event", ->
      assert.equal events.active.name, "open-test"


  describe "closing a window", ->
    before ->
      browser.on "closed", (window)->
        events.close = window
      browser.on "inactive", (window)->
        events.inactive = window
      window = browser.open(name: "close-test")
      window.close()

    it "should receive closed event", ->
      assert.equal events.close.name, "close-test"

    it "should receive inactive event", ->
      assert.equal events.active.name, "open-test"


  describe "loading a document", ->
    before (done)->
      brains.get "/browser-events/document", (req, res)->
        res.send "<html>Very well then</html>"

      browser.on "loading", (document)->
        events.loading = [document.URL, document.readyState, document.outerHTML]
      browser.on "loaded", (document)->
        events.loaded = [document.URL, document.readyState, document.outerHTML]

      browser.visit "/browser-events/document", done

    it "should receive loading event", ->
      [url, readyState, html] = events.loading
      assert.equal url, "http://localhost:3003/browser-events/document"
      assert.equal readyState, "loading"
      assert.equal html, ""

    it "should receive loaded event", ->
      [url, readyState, html] = events.loaded
      assert.equal url, "http://localhost:3003/browser-events/document"
      assert.equal readyState, "complete"
      assert /Very well then/.test(html)


  describe "firing an event", ->
    before (done)->
      browser.load("<html><body>Hello</body></html>")

      browser.on "event", (event, target)->
        if event.type == "click"
          events.click = { event: event, target: target }

      browser.click("body")
      browser.wait(done)

    it "should receive DOM event", ->
      assert.equal events.click.event.type, "click"

    it "should receive DOM event target", ->
      assert.equal events.click.target, browser.document.body


  describe "changing focus", ->
    before (done)->
      brains.get "/browser-events/focus", (req, res)->
        res.send """
        <html>
          <input id="input">
          <script>document.getElementById("input").focus()</script>
        </html>
        """

      browser.on "focus", (element)->
        events.focus = element

      browser.visit "/browser-events/focus", done

    it "should receive focus event", ->
      element = events.focus
      assert.equal element.id, "input"


  describe "timeout fired", ->
    before (done)->
      brains.get "/browser-events/timeout", (req, res)->
        res.send """
        <html>
          <script>setTimeout(function() { }, 1);</script>
        </html>
        """

      browser.on "timeout", (fn, delay)->
        events.timeout = { fn: fn, delay: delay }

      browser.visit "/browser-events/timeout", done

    it "should receive timeout event with the function", ->
      assert.equal typeof(events.timeout.fn), "function"

    it "should receive timeout event with the delay", ->
      assert.equal events.timeout.delay, 1


  describe "interval fired", ->
    before (done)->
      brains.get "/browser-events/interval", (req, res)->
        res.send """
        <html>
          <script>setInterval(function() { }, 2);</script>
        </html>
        """

      browser.on "interval", (fn, interval)->
        events.interval = { fn: fn, interval: interval }

      browser.visit("/browser-events/interval")
      browser.wait(duration: 100, done)

    it "should receive interval event with the function", ->
      assert.equal typeof(events.interval.fn), "function"

    it "should receive interval event with the interval", ->
      assert.equal events.interval.interval, 2


  describe "event loop empty", ->
    before (done)->
      brains.get "/browser-events/done", (req, res)->
        res.send """
        <html>
          <script>setTimeout(function() { }, 1);</script>
        </html>
        """

      browser.on "done", ->
        events.done = true

      browser.visit("/browser-events/done")
      events.done = false
      browser.wait(done)

    it "should receive done event", ->
      assert events.done


  describe "evaluated", ->
    before (done)->
      brains.get "/browser-events/evaluated", (req, res)->
        res.send """
        <html>
          <script>window.foo = true</script>
        </html>
        """

      browser.on "evaluated", (code, result, filename)->
        events.evaluated = { code: code, result: result, filename: filename }

      browser.visit("/browser-events/evaluated", done)

    it "should receive evaluated event with the code", ->
      assert.equal events.evaluated.code, "window.foo = true"

    it "should receive evaluated event with the result", ->
      assert.equal events.evaluated.result, true

    it "should receive evaluated event with the filename", ->
      assert.equal events.evaluated.filename, "http://localhost:3003/browser-events/evaluated:script"


  describe "link", ->
    before (done)->
      brains.get "/browser-events/link", (req, res)->
        res.send "<html><a href='follow'></a></html>"

      browser.on "link", (url, target)->
        events.link = { url: url, target: target }

      browser.visit "/browser-events/link", ->
        browser.click("a")
        done()

    it "should receive link event with the URL", ->
      assert.equal events.link.url, "http://localhost:3003/browser-events/follow"
    it "should receive link event with the target", ->
      assert.equal events.link.target, "_self"


  describe "submit", ->
    before (done)->
      brains.get "/browser-events/submit", (req, res)->
        res.send("<html><form action='post'></form></html>")

      brains.get "/browser-events/post", (req, res)->
        res.send("<html>Got it!</html>")

      browser.on "submit", (url, target)->
        events.link = { url: url, target: target }

      browser.visit "/browser-events/submit", ->
        browser.query("form").submit()
        browser.wait(done)

    it "should receive submit event with the URL", ->
      assert.equal events.link.url, "http://localhost:3003/browser-events/post"
    it "should receive submit event with the target", ->
      assert.equal events.link.target, "_self"


  after ->
    browser.destroy()
