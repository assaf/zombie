{ assert, brains, Browser } = require("./helpers")


describe "IFrame", ->

  browser = null
  before (done)->
    browser = Browser.create()
    brains.ready(done)

  before ->
    brains.get "/iframe", (req, res)->
      res.send """
      <html>
        <head>
          <script src="/jquery.js"></script>
        </head>
        <body>
          <iframe name="ever"></iframe>
          <script>
            var frame = document.getElementsByTagName("iframe")[0];
            frame.src = "/iframe/static";
            frame.onload = function() {
              document.title = frame.contentDocument.title;
            }
          </script>
        </body>
      </html>
      """
    brains.get "/iframe/static", (req, res)->
      res.send """
      <html>
        <head>
          <title>What</title>
        </head>
        <body>Hello World</body>
        <script>
          document.title = document.title + window.name;
        </script>
      </html>
      """

  before (done)->
    browser.visit("/iframe")
      .then =>
        @iframe = browser.querySelector("iframe")
        return
      .then(done, done)

  it "should fire onload event", ->
    browser.assert.text "title", "Whatever"
  it "should load iframe document", ->
    iframeDocument = @iframe.contentWindow.document
    assert.equal "Whatever", iframeDocument.title
    assert /Hello World/.test(iframeDocument.innerHTML)
    assert.equal iframeDocument.URL, "http://localhost:3003/iframe/static"
  it "should set frame src attribute", ->
    assert.equal @iframe.src, "/iframe/static"
  it "should reference parent window from iframe", ->
    assert.equal @iframe.contentWindow.parent, browser.window.parent
  it "should not alter the parent", ->
    browser.assert.url "http://localhost:3003/iframe"

  describe "javascript: protocol", ->
    # Seen this in the wild, checking that it doesn't blow up
    before (done)->
      @iframe.src = "javascript:false"
      browser.wait(done)

    it "should not blow up", ->
      assert true

  describe "postMessage", ->
    before (done)->
      brains.get "/iframe/ping", (req, res)->
        res.send """
        <html>
          <body>
            <iframe name="ping" src="/iframe/pong"></iframe>
            <script>
              // Give the frame a chance to load before sending message
              var iframe = document.getElementsByTagName("iframe")[0];
              iframe.addEventListener("load", function() {
                window.frames["ping"].postMessage("ping");
              })
              // Ready to receive response
              window.addEventListener("message", function(event) {
                document.title = event.data;
              })
            </script>
          </body>
        </html>
        """
      brains.get "/iframe/pong", (req, res)->
        res.send """
        <script>
          window.addEventListener("message", function(event) {
            if (event.data == "ping")
              event.source.postMessage("pong " + event.origin);
          })
        </script>
        """
      brains.ready done

    before (done)->
      browser.visit("/iframe/ping", done)

    it "should pass messages back and forth", ->
      browser.assert.text "title", "pong http://localhost:3003"


  describe "link target", ->
    before (done)->
      brains.get "/iframe/top", (req, res)->
        res.send """
          <a target="_self" href="/target/_self">self</a>
          <a target="_blank" href="/target/_blank">blank</a>
          <iframe name="child" src="/iframe/child"></iframe>
          <a target="new-window" href="/target/new-window">new window</a>
          <a target="new-window" href="/target/existing-window">existing window</a>
        """
      brains.get "/iframe/child", (req, res)->
        res.send """
          <iframe name="child" src="/iframe/grand-child"></iframe>
        """
      brains.get "/iframe/grand-child", (req, res)->
        res.send """
          <a target="_parent" href="/target/_parent">blank</a>
          <a target="_top" href="/target/_top">blank</a>
        """
      brains.get "/target/_self", (req, res)-> res.send ""
      brains.get "/target/_blank", (req, res)-> res.send ""
      brains.get "/target/_parent", (req, res)-> res.send ""
      brains.get "/target/_top", (req, res)-> res.send ""
      brains.get "/target/new-window", (req, res)-> res.send ""
      brains.get "/target/existing-window", (req, res)-> res.send ""
      brains.ready done


    describe "_self", ->
      source = null

      before (done)->
        browser.visit "/iframe/top", =>
          @source = browser.window
          browser.clickLink("self", done)

      it "should open link", ->
        browser.assert.url pathname: "/target/_self"

      it "should open link in same window", ->
        assert.equal browser.tabs.index, 0


    describe "_blank", ->

      before (done)->
        browser.visit "/iframe/top", ->
          assert.equal browser.tabs.length, 1
          browser.clickLink("blank", done)

      it "should open link", ->
        browser.assert.url pathname: "/target/_blank"

      it "should open link in new window", ->
        assert.equal browser.tabs.length, 2
        assert.equal browser.tabs.index, 1

      after ->
        browser.close()


    describe "_top", ->
      before (done)->
        browser.visit "/iframe/top", ->
          twoDeep = browser.window.frames["child"].frames["child"].document
          link = twoDeep.querySelector("a[target=_top]")

          event = link.ownerDocument.createEvent("HTMLEvents")
          event.initEvent("click", true, true)
          link.dispatchEvent(event)
          browser.wait(done)

      it "should open link", ->
        browser.assert.url pathname: "/target/_top"

      it "should open link in top window", ->
        assert.equal browser.tabs.length, 1


    describe "_parent", ->
      before (done)->
        browser.visit "/iframe/top", ->
          twoDeep = browser.window.frames["child"].frames["child"].document
          link = twoDeep.querySelector("a[target=_parent]")

          event = link.ownerDocument.createEvent("HTMLEvents")
          event.initEvent("click", true, true)
          link.dispatchEvent(event)
          browser.wait(done)

      it "should open link", ->
        assert.equal browser.window.frames["child"].location.pathname, "/target/_parent"

      it "should open link in child window", ->
        browser.assert.url pathname: "/iframe/top"
        assert.equal browser.tabs.length, 1


    describe "window", ->

      describe "new", ->
        before (done)->
          browser.visit "/iframe/top", ->
            browser.clickLink("new window", done)

        it "should open link", ->
          browser.assert.url pathname: "/target/new-window"

        it "should open link in new window", ->
          assert.equal browser.tabs.length, 2
          assert.equal browser.tabs.index, 1

        after ->
          browser.close()


      describe "existing", ->
        before (done)->
          browser.visit "/iframe/top", ->
            browser.clickLink("new window", done)

        before (done)->
          browser.tabs.current = 0
          browser.clickLink("existing window", done)

        it "should open link", ->
          browser.assert.url pathname: "/target/existing-window"

        it "should open link in existing window", ->
          assert.equal browser.tabs.length, 2

        it "should select existing window", ->
          assert.equal browser.tabs.index, 1

        after ->
          browser.close(1)


  after ->
    browser.destroy()
