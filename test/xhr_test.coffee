{ assert, brains, Browser } = require("./helpers")


describe "XMLHttpRequest", ->

  browser = null
  before ->
    browser = Browser.create()

  describe "asynchronous", ->
    before (done)->
      brains.get "/xhr/async", (req, res)->
        res.send """
        <html>
          <head><script src="/jquery.js"></script></head>
          <body>
            <script>
              document.title = "One";
              window.foo = "bar";
              $.get("/xhr/async/backend", function(response) {
                window.foo += window.foo;
                document.title += response;
              });
              document.title += "Two";
            </script>
          </body>
        </html>
        """
      brains.get "/xhr/async/backend", (req, res)->
        res.send "Three"
      brains.ready done

    before (done)->
      browser.visit("http://localhost:3003/xhr/async", done)

    it "should load resource asynchronously", ->
      browser.assert.text "title", "OneTwoThree"
    it "should run callback in global context", ->
      browser.assert.global "foo", "barbar"


  describe "response headers", ->
    before (done)->
      brains.get "/xhr/headers", (req, res)->
        res.send """
        <html>
          <head><script src="/jquery.js"></script></head>
          <body>
            <script>
              $.get("/xhr/headers/backend", function(data, textStatus, jqXHR) {
                document.allHeaders = jqXHR.getAllResponseHeaders();
                document.headerOne = jqXHR.getResponseHeader('Header-One');
                document.headerThree = jqXHR.getResponseHeader('header-three');
              });
            </script>
          </body>
        </html>
        """
      brains.get "/xhr/headers/backend", (req, res)->
        res.setHeader "Header-One", "value1"
        res.setHeader "Header-Two", "value2"
        res.setHeader "Header-Three", "value3"
        res.send ""
      brains.ready done

    before (done)->
      browser.visit("http://localhost:3003/xhr/headers", done)

    it "should return all headers as string", ->
      assert ~browser.document.allHeaders.indexOf("header-one: value1\nheader-two: value2\nheader-three: value3")
    it "should return individual headers", ->
      assert.equal browser.document.headerOne, "value1"
      assert.equal browser.document.headerThree, "value3"


  describe "cookies", ->
    before (done)->
      brains.get "/xhr/cookies", (req, res)->
        res.cookie "xhr", "send", path: "/xhr"
        res.send """
        <html>
          <head><script src="/jquery.js"></script></head>
          <body>
            <script>
              $.get("/xhr/cookies/backend", function(cookie) {
                document.received = cookie;
              });
            </script>
          </body>
        </html>
        """
      brains.get "/xhr/cookies/backend", (req, res)->
        cookie = req.cookies["xhr"]
        res.cookie "xhr", "return", path: "/xhr"
        res.send cookie
      brains.ready done

    before (done)->
      browser.visit("http://localhost:3003/xhr/cookies", done)

    it "should send cookies to XHR request", ->
      assert.equal browser.document.received, "send"
    it "should return cookies from XHR request", ->
      assert /xhr=return/.test(browser.document.cookie)


  describe "redirect", ->
    before (done)->
      brains.get "/xhr/redirect", (req, res)-> res.send """
        <html>
          <head><script src="/jquery.js"></script></head>
          <body>
            <script>
              $.get("/xhr/redirect/backend", function(response) { window.response = response });
            </script>
          </body>
        </html>
        """
      brains.get "/xhr/redirect/backend", (req, res)->
        res.redirect "/xhr/redirect/target"
      brains.get "/xhr/redirect/target", (req, res)->
        res.send "redirected " + req.headers["x-requested-with"]
      brains.ready done

    before (done)->
      browser.visit("http://localhost:3003/xhr/redirect", done)

    it "should follow redirect", ->
      assert /redirected/.test(browser.window.response)
    it "should resend headers", ->
      assert /XMLHttpRequest/.test(browser.window.response)


  describe "handle POST requests with no data", ->
    before (done)->
      brains.get "/xhr/post/empty", (req, res)->
        res.send """
        <html>
          <head><script src="/jquery.js"></script></head>
          <body>
            <script>
              $.post("/xhr/post/empty", function(response, status, xhr) { document.title = xhr.status + response });
            </script>
          </body>
        </html>
        """
      brains.post "/xhr/post/empty", (req, res)->
        res.send "posted", 201
      brains.ready done

    before (done)->
      browser.visit("http://localhost:3003/xhr/post/empty", done)

    it "should post with no data", ->
      browser.assert.text "title", "201posted"


  describe "empty response", ->
    before (done)->
      brains.get "/xhr/get-empty", (req, res)->
        res.send """
        <html>
          <head><script src="/jquery.js"></script></head>
          <body>
            <script>
              $.get("/xhr/empty", function(response, status, xhr) {
                document.text = xhr.responseText;
              });
            </script>
          </body>
        </html>
        """
      brains.get "/xhr/empty", (req, res)->
        res.send ""
      brains.ready done

    before (done)->
      browser.visit("http://localhost:3003/xhr/get-empty", done)

    it "responseText should be an empty string", ->
      assert.strictEqual "", browser.document.text


  describe "response text", ->
    before (done)->
      brains.get "/xhr/get-utf8-octet-stream", (req, res)->
        res.send """
        <html>
          <head><script src="/jquery.js"></script></head>
          <body>
            <script>
              $.get("/xhr/utf8-octet-stream", function(response, status, xhr) {
                document.text = xhr.responseText;
              });
            </script>
          </body>
        </html>
        """
      brains.get "/xhr/utf8-octet-stream", (req, res)->
        res.type "application/octet-stream"
        res.send "Text"
      brains.ready done

    before (done)->
      browser.visit("http://localhost:3003/xhr/get-utf8-octet-stream", done)

    it "responseText should be a string", ->
      assert.equal "string", typeof browser.document.text
      assert.equal "Text", browser.document.text

  describe "xhr onreadystatechange", ->
    before (done)->
      brains.get "/xhr/get-onreadystatechange", (req, res)->
        res.send """
        <html>
          <head></head>
          <body>
            <script>
              document.readyStatesReceived = { 1:[], 2:[], 3:[], 4:[] };
              var xhr = new XMLHttpRequest();
              xhr.onreadystatechange = function(){
                document.readyStatesReceived[xhr.readyState].push(Date.now())
              };

              xhr.open("GET", "/xhr/onreadystatechange", true);
              xhr.send();

            </script>
          </body>
        </html>
        """
      brains.get "/xhr/onreadystatechange", (req, res)->
        res.send("foo")

      brains.ready done

    before (done)->
      browser.visit("http://localhost:3003/xhr/get-onreadystatechange", done)

    it "should get exactly one readyState of type 1, 2, and 4", ->
      assert.equal browser.document.readyStatesReceived[1].length, 1
      assert.equal browser.document.readyStatesReceived[2].length, 1
      assert.equal browser.document.readyStatesReceived[4].length, 1

    it "should get the readyStateChanges in chronological order", ->
      assert (browser.document.readyStatesReceived[1][0] <=
              browser.document.readyStatesReceived[2][0])

      assert (browser.document.readyStatesReceived[2][0] <=
              browser.document.readyStatesReceived[4][0])

  describe.skip "HTML document", ->
    before (done)->
      brains.get "/xhr/get-html", (req, res)->
        res.send """
        <html>
          <head><script src="/jquery.js"></script></head>
          <body>
            <script>
              $.get("/xhr/html", function(response, status, xhr) {
                document.body.appendChild(xhr.responseXML);
              });
            </script>
          </body>
        </html>
        """
      brains.get "/xhr/html", (req, res)->
        res.type("text/html")
        res.send("<foo><bar id='bar'></foo>")
      brains.ready done

    before (done)->
      browser.visit("http://localhost:3003/xhr/get-html", done)

    it "should parse HTML document", ->
      browser.assert.element "foo > bar#bar"


  after ->
    browser.destroy()
