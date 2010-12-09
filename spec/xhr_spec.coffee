vows = require("vows", "assert")
assert = require("assert")
{ server: server, visit: visit } = require("./helpers")


server.get "/xhr", (req, res)->
  res.send """
           <html>
             <head><script src="/jquery.js"></script></head>
             <body>
               <script>
                 $.get("/text", function(response) { window.response = response });
               </script>
             </body>
           </html>
           """
server.get "/text", (req, res)-> res.send "XMLOL"


vows.describe("XMLHttpRequest").addBatch({
  "load asynchronously":
    visit "http://localhost:3003/xhr"
      ready: (err, window)-> window.wait @callback
      "should load resource": (window)-> assert.equal window.response, "XMLOL"
}).export(module);
