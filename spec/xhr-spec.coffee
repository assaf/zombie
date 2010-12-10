require("./helpers")
{ vows: vows, assert: assert, zombie: zombie, brains: brains } = require("vows")

brains.get "/xhr", (req, res)-> res.send """
  <html>
    <head><script src="/jquery.js"></script></head>
    <body>
      <script>
        $.get("/text", function(response) { window.response = response });
      </script>
    </body>
  </html>
  """
brains.get "/text", (req, res)->
  res.send "XMLOL"


vows.describe("XMLHttpRequest").addBatch({
  "load asynchronously":
    zombie.wants "http://localhost:3003/xhr"
      ready: (err, window)-> window.wait @callback
      "should load resource": (window)-> assert.equal window.response, "XMLOL"
}).export(module);
