require("./helpers")
{ vows: vows, assert: assert, zombie: zombie, brains: brains } = require("vows")


brains.get "/timeout", (req, res)->
  res.send """
           <html>
             <head><title>One</title></head>
             <body>
               <script>
                 window.second = window.setTimeout(function() { document.title = document.title + " Three" }, 5000);
                 window.first = window.setTimeout(function() { document.title = document.title + " Two" }, 1000);
               </script>
             </body>
           </html>
           """

brains.get "/interval", (req, res)->
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



vows.describe("EventLoop").addBatch({
  "setTimeout":
    "no wait":
      zombie.wants "http://localhost:3003/timeout"
        "should not fire any timeout events": (window)-> assert.equal window.document.title, "One"
        "should not change clock": (window) -> assert.equal window.clock, 0
    "wait for all":
      zombie.wants "http://localhost:3003/timeout"
        ready: (err, window)-> window.wait @callback
        "should fire all timeout events": (window)-> assert.equal window.document.title, "One Two Three"
        "should move clock forward": (window) -> assert.equal window.clock, 5000
    "cancel timeout":
      zombie.wants "http://localhost:3003/timeout"
        ready: (err, window)->
          terminate = ->
            window.clearTimeout window.second
            false
          window.wait terminate, @callback
        "should fire only uncancelled timeout events": (window)->
          assert.equal window.document.title, "One Two"
          assert.equal window.clock, 1000

  "setInterval":
    "no wait":
      zombie.wants "http://localhost:3003/interval"
        "should not fire any timeout events": (window)-> assert.equal window.document.title, ""
        "should not change clock": (window) -> assert.equal window.clock, 0
    "wait for five":
      zombie.wants "http://localhost:3003/interval"
        ready: (err, window)-> window.wait 5, @callback
        "should fire five interval event": (window)-> assert.equal window.document.title, "....."
        "should move clock forward": (window) -> assert.equal window.clock, 5000
    "cancel interval":
      zombie.wants "http://localhost:3003/interval"
        ready: (err, window)->
          window.wait 5, =>
            window.clearInterval window.interval
            window.wait 5, @callback
        "should fire only uncancelled interval events": (window)->
          assert.equal window.document.title, "....."
          assert.equal window.clock, 5000
}).export(module);
