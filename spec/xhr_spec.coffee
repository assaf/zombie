{ Vows, assert, brains, Browser } = require("./helpers")


Vows.describe("XMLHttpRequest").addBatch(
  "asynchronous":
    topic: ->
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
      browser = new Browser
      browser.wants "http://localhost:3003/xhr/async", @callback
    "should load resource asynchronously": (browser)->
      assert.equal browser.window.title, "OneTwoThree"
    "should run callback in global context": (browser)->
      assert.equal browser.window.foo, "barbar"


  "response headers":
    topic: ->
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
      browser = new Browser
      browser.wants "http://localhost:3003/xhr/headers", @callback
    "should return all headers as string": (browser)->
      assert.include browser.document.allHeaders, "header-one: value1\nheader-two: value2\nheader-three: value3"
    "should return individual headers": (browser)->
      assert.equal browser.document.headerOne, "value1"
      assert.equal browser.document.headerThree, "value3"


  "cookies":
    topic: ->
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
      browser = new Browser
      browser.wants "http://localhost:3003/xhr/cookies", @callback
    "should send cookies to XHR request": (browser)->
      assert.include browser.document.values, "send"
    "should return cookies from XHR request": (browser)->
      assert.include browser.document.values, "return"
  

  "redirect":
    topic: ->
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
      browser = new Browser
      browser.wants "http://localhost:3003/xhr/redirect", @callback
    "should follow redirect": (browser)->
      assert.match browser.window.response, /redirected/
    "should resend headers": (browser)->
      assert.match browser.window.response, /XMLHttpRequest/


  "handle POST requests with no data":
    topic: ->
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
      browser = new Browser
      browser.wants "http://localhost:3003/xhr/post/empty", @callback
    "should post with no data": (browser)->
      assert.equal browser.document.title, "201posted"

).export(module)
