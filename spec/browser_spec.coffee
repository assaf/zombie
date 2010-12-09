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

server.get "/timeout", (req, res)->
  res.send """
           <html>
             <head><title>Starting point</title></head>
             <body>
               <script>
                 window.second = window.setTimeout(function() { document.title = "Four later" }, 5000);
                 window.first = window.setTimeout(function() { document.title = "Second later" }, 1000);
               </script>
             </body>
           </html>
           """

server.get "/interval", (req, res)->
  res.send """
           <html>
             <head><title></title></head>
             <body>
               <script>
                 window.interval = window.setInterval(function() { document.title = document.title + "." }, 1000);
               </script>
             </body>
           </html>
           """


vows.describe("Browser").addBatch({
  "open page":
    visit "http://localhost:3003/scripted"
      "should create HTML document": (window)-> assert.instanceOf window.document, jsdom.dom.level3.html.HTMLDocument
      "should load document from server": (window)-> assert.match window.document.outerHTML, /<body>Hello World<\/body>/
      "should load external scripts": (window)->
        assert.ok jQuery = window.jQuery, "window.jQuery not available"
        assert.typeOf jQuery.ajax, "function"
      "should run jQuery.onready": (window)-> assert.equal window.document.title, "Awesome"

  "setTimeout":
    "single step":
      visit "http://localhost:3003/timeout"
        "should not fire timeout events": (window)-> assert.equal window.document.title, "Starting point"
        "process once":
          topic: (window)-> window.process()
          "should fire first timeout event": (window)-> assert.equal window.document.title, "Second later"
          "should move clock forward": (window) -> assert.equal window.clock, 1000
          "process twice":
            topic: (window)-> window.process()
            "should fire second timeout event": (window)-> assert.equal window.document.title, "Four later"
            "should move clock forward": (window) -> assert.equal window.clock, 5000
            "process again":
              topic: (window)-> window.process()
              "should do nothing interesting": (window)-> assert.equal window.document.title, "Four later"
              "should move clock forward": (window) -> assert.equal window.clock, 5000
    "batch":
      visit "http://localhost:3003/timeout"
        ready: (err, window)->
          window.process (window)->
          @callback err, window
        "should fire all timeout events": (window)-> assert.equal window.document.title, "Four later"
        "should move clock forward": (window) -> assert.equal window.clock, 5000
    "cancel timeout":
      visit "http://localhost:3003/timeout"
        ready: (err, window)->
          window.process (window)->
            window.clearTimeout(window.second)
          @callback err, window
        "should fire only uncancelled timeout events": (window)->
          assert.equal window.document.title, "Second later"
          assert.equal window.clock, 1000

  "setInterval":
    "single step":
      visit "http://localhost:3003/interval"
        "should not fire timeout events": (window)-> assert.equal window.document.title, ""
        "process once":
          topic: (window)-> window.process()
          "should fire interval event": (window)-> assert.equal window.document.title, "."
          "should move clock forward": (window) -> assert.equal window.clock, 1000
          "process twice":
            topic: (window)-> window.process()
            "should fire interval event": (window)-> assert.equal window.document.title, ".."
            "should move clock forward": (window) -> assert.equal window.clock, 2000
    "batch":
      visit "http://localhost:3003/interval"
        ready: (err, window)->
          window.process (window)-> window.document.title.length < 5
          @callback err, window
        "should fire multiple interval events": (window)-> assert.equal window.document.title, "....."
        "should move clock forward": (window) -> assert.equal window.clock, 5000
    "cancel interval":
      visit "http://localhost:3003/interval"
        ready: (err, window)->
          window.process (window)->
            window.clearInterval(window.interval) if window.document.title.length >= 5
            return
          @callback err, window
        "should fire only uncancelled interval events": (window)->
          assert.equal window.document.title, "....."
          assert.equal window.clock, 5000
}).export(module);
