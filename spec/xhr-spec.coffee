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
  res.send req.cookies["xhr"]


vows.describe("XMLHttpRequest").addBatch(
  "load asynchronously":
    zombie.wants "http://localhost:3003/xhr"
      "should load resource": (browser)-> assert.ok browser.window.response

  "send cookies":
    zombie.wants "http://localhost:3003/xhr"
      "should send cookies in XHR response": (browser)-> assert.equal browser.window.response, "yes"

  "receive cookies":
    zombie.wants "http://localhost:3003/xhr"
      "should process cookies in XHR response": (browser)-> assert.equal browser.cookies.get("xml"), "lol"
).export(module)
