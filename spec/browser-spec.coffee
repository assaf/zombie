require("./helpers")
{ vows: vows, assert: assert, zombie: zombie, brains: brains } = require("vows")
jsdom = require("jsdom")


brains.get "/scripted", (req, res)->
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
    zombie.wants "http://localhost:3003/scripted"
      "should create HTML document": (window)-> assert.instanceOf window.document, jsdom.dom.level3.html.HTMLDocument
      "should load document from server": (window)-> assert.match window.document.outerHTML, /<body>Hello World<\/body>/
      "should load external scripts": (window)->
        assert.ok jQuery = window.jQuery, "window.jQuery not available"
        assert.typeOf jQuery.ajax, "function"
      "should run jQuery.onready": (window)-> assert.equal window.document.title, "Awesome"
}).export(module);
