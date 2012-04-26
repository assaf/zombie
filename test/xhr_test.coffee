{ Vows, assert, brains, Browser } = require("./helpers")


describe "XMLHttpRequest", ->

  describe "asynchronous", ->
    browser = new Browser()

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
      brains.ready ->
        browser.visit "http://localhost:3003/xhr/async", done

    it "should load resource asynchronously", ->
      assert.equal browser.window.title, "OneTwoThree"
    it "should run callback in global context", ->
      assert.equal browser.window.foo, "barbar"


  describe "response headers", ->
    browser = new Browser()

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
      brains.ready ->
        browser.visit "http://localhost:3003/xhr/headers", done

    it "should return all headers as string", ->
      assert ~browser.document.allHeaders.indexOf("header-one: value1\nheader-two: value2\nheader-three: value3")
    it "should return individual headers", ->
      assert.equal browser.document.headerOne, "value1"
      assert.equal browser.document.headerThree, "value3"


  describe "cookies", ->
    browser = new Browser()

    before (done)->
      brains.get "/xhr/cookies", (req, res)->
        res.cookie "xhr", "send", path: "/"
        res.send """
        <html>
          <head><script src="/jquery.js"></script></head>
          <body>
            <script>
              $.get("/xhr/cookies/backend", function(response) {
                var returned = document.cookie.split("=")[1];
                document.values = [response, returned]
              });
            </script>
          </body>
        </html>
        """
      brains.get "/xhr/cookies/backend", (req, res)->
        cookie = req.cookies["xhr"]
        res.cookie "xhr", "return", path: "/"
        res.send cookie
      brains.ready ->
        browser.visit "http://localhost:3003/xhr/cookies", done

    it "should send cookies to XHR request", ->
      assert ~browser.document.values.indexOf("send")
    it "should return cookies from XHR request", ->
      assert ~browser.document.values.indexOf("return")
  

  describe "redirect", ->
    browser = new Browser()

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
      brains.ready ->
        browser.visit "http://localhost:3003/xhr/redirect", done

    it "should follow redirect", ->
      assert /redirected/.test(browser.window.response)
    it "should resend headers", ->
      assert /XMLHttpRequest/.test(browser.window.response)


  describe "handle POST requests with no data", ->
    browser = new Browser()

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
      brains.ready ->
        browser.visit "http://localhost:3003/xhr/post/empty", done

    it "should post with no data", ->
      assert.equal browser.document.title, "201posted"

