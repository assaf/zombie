require.paths.push(__dirname)
vows = require("vows", "assert")
assert = require("assert")
jsdom = require("jsdom")
{ server: server, visit: visit } = require("helpers")


server.get "/scripted", (req, res)->
  res.send """
           <html>
             <head>
               <title>Whatever</title>
               <script src="/jquery.js"></script>
             </head>
             <body>Hello World</body>
             <script>
                $(function() { $("title").text("Awesome") })
             </script>
           </html>
           """


vows.describe("Browser").addBatch({
  "open page":
    visit "http://localhost:3003/scripted"
      "callback with document": (window)-> assert.instanceOf window.document, jsdom.dom.level3.html.HTMLDocument
      "load document": (window)-> assert.match window.document.outerHTML, /<body>Hello World<\/body>/
      "load scripts": (window)->
        assert.ok jQuery = window.jQuery, "window.jQuery not available"
        assert.typeOf jQuery.ajax, "function"
      "run jQuery scripts": (window)-> assert.equal window.document.title, "Awesome"
}).export(module);
