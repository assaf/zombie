require("./helpers")
{ vows: vows, assert: assert, zombie: zombie, brains: brains } = require("vows")

brains.get "/xhr", (req, res)->
  res.cookie "xhr", "yes", "Path": "/"
  res.send """
  <html>
    <head><script src="/jquery.js"></script></head>
    <body>
      <script>
        $.get("/xhr/backend", function(response) { window.response = response });
      </script>
    </body>
  </html>
  """
brains.get "/xhr/backend", (req, res)->
  res.cookie "xml", "lol", "Path": "/"
  response = req.cookies["xhr"] || ""
  response = "redirected: #{response}" if req.query.redirected
  res.send response

brains.get "/xhr/redirect", (req, res)->
  res.cookie "xhr", "yes", "Path": "/"
  res.send """
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
  res.redirect "/xhr/backend?redirected=true"

brains.get "/xhr/parturl", (req, res)-> res.send """
  <html>
    <head><script src="/jquery.js"></script></head>
    <body>
      <script>
        $.get("http://:3003", function(response) { window.response = "ok" });
      </script>
    </body>
  </html>
  """

brains.get "/xhr/postempty", (req, res)-> res.send """
  <html>
    <head><script src="/jquery.js"></script></head>
    <body>
      <script>
        $.post("/xhr/postempty", function(response) { window.response = "ok" });
      </script>
    </body>
  </html>
  """
brains.post "/xhr/postempty", (req, res)-> res.send ""


vows.describe("XMLHttpRequest").addBatch(
  "load asynchronously":
    zombie.wants "http://localhost:3003/xhr"
      "should load resource": (browser)-> assert.ok browser.window.response

  "send cookies":
    zombie.wants "http://localhost:3003/xhr"
      "should send cookies in XHR response": (browser)-> assert.equal browser.window.response, "yes"

  "receive cookies":
    zombie.wants "http://localhost:3003/xhr"
      "should process cookies in XHR response": (browser)-> assert.equal browser.window.cookies.get("xml"), "lol"

  "redirect":
    zombie.wants "http://localhost:3003/xhr/redirect"
      "should send cookies in XHR response": (browser)-> assert.equal browser.window.response, "redirected: yes"

  "handle partial URLs":
    # If the request URL is http://:3003 it means use the current document's hostname, but the port 3003.
    zombie.wants "http://localhost:3003/xhr/parturl"
      "should resolve partial URL": (browser)-> assert.equal browser.window.response, "ok"

  "handle POST requests with no data":
    zombie.wants "http://localhost:3003/xhr/postempty"
      "should post with no data": (browser)-> assert.equal browser.window.response, "ok"

).export(module)
