require("./helpers")
{ vows: vows, assert: assert, zombie: zombie, brains: brains } = require("vows")

brains.get "/xhr", (req, res)->
  res.cookie "xhr", "yes", "Path": "/"
  res.send """
  <html>
    <head><script src="/jquery.js"></script></head>
    <body>
      <script>
        $.get("/backend", function(response) { window.response = response });
      </script>
    </body>
  </html>
  """
brains.get "/backend", (req, res)->
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
        $.get("/backend/redirect", function(response) { window.response = response });
      </script>
    </body>
  </html>
  """
brains.get "/backend/redirect", (req, res)->
  res.redirect "/backend?redirected=true"


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
).export(module)
