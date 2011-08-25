require("./helpers")
{ vows: vows, assert: assert, Browser: Browser, brains: brains } = require("vows")


vows.describe("XMLHttpRequest").addBatch(
  "asynchronous":
    topic: ->
      brains.get "/xhr/async", (req, res)-> res.send """
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
      brains.get "/xhr/async/backend", (req, res)-> res.send "Three"
      browser = new Browser
      browser.wants "http://localhost:3003/xhr/async", @callback
    "should load resource asynchronously": (browser)->
      assert.equal browser.window.title, "OneTwoThree"
    "should run callback in global context": (browser)->
      assert.equal browser.window.foo, "barbar"

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
    "should send cookies to XHR request": (browser)-> assert.include browser.document.values, "send"
    "should return cookies from XHR request": (browser)-> assert.include browser.document.values, "return"
     
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
        res.send "redirected"
      browser = new Browser
      browser.wants "http://localhost:3003/xhr/redirect", @callback
    "should follow redirect": (browser)-> assert.equal browser.window.response, "redirected"

  "handle POST requests with no data":
    topic: ->
      brains.get "/xhr/post/empty", (req, res)-> res.send """
        <html>
          <head><script src="/jquery.js"></script></head>
          <body>
            <script>
              $.post("/xhr/post/empty", function(response, status, xhr) { document.title = xhr.status + response });
            </script>
          </body>
        </html>
        """
      brains.post "/xhr/post/empty", (req, res)-> res.send "posted", 201
      browser = new Browser
      browser.wants "http://localhost:3003/xhr/post/empty", @callback
    "should post with no data": (browser)-> assert.equal browser.document.title, "201posted"

).export(module)
