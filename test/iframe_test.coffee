{ assert, brains, Browser } = require("./helpers")


describe "IFrame", ->

  before (done)->
    brains.get "/iframe", (req, res)->
      res.send """
      <html>
        <head>
          <script src="/jquery.js"></script>
        </head>
        <body>
          <iframe name="ever"></iframe>
          <script>
            var frame = document.getElementsByTagName("iframe")[0];
            frame.src = "/iframe/static";
            frame.onload = function() {
              document.title = frame.contentDocument.title;
            }
          </script>
        </body>
      </html>
      """
    brains.get "/iframe/static", (req, res)->
      res.send """
      <html>
        <head>
          <title>What</title>
        </head>
        <body>Hello World</body>
        <script>
          document.title = document.title + window.name;
        </script>
      </html>
      """
    brains.ready done

  browser = new Browser()
  iframe = null

  before (done)->
    browser.visit "http://localhost:3003/iframe", ->
      iframe = browser.querySelector("iframe")
      done()

  it "should fire onload event", ->
    assert.equal browser.document.title, "Whatever"
  it "should load iframe document", ->
    document = iframe.contentWindow.document
    assert.equal "Whatever", document.title
    assert /Hello World/.test(document.innerHTML)
    assert.equal document.location, "http://localhost:3003/iframe/static"
  it "should reference parent window from iframe", ->
    assert.equal iframe.contentWindow.parent, browser.window.top
  it "should not alter the parent", ->
    assert.equal "http://localhost:3003/iframe", browser.window.location


  it "should handle javascript protocol gracefully", ->
    # Seen this done before, shouldn't trip Zombie
    iframe.src = "javascript:false"
    assert true


describe "postMessage", ->
  browser = new Browser()

  before (done)->
    brains.get "/iframe/ping", (req, res)->
      res.send """
      <html>
        <body>
          <iframe></iframe>
          <script>
            var frame = document.getElementsByTagName("iframe")[0];
            // Ready to receive response
            window.addEventListener("message", function(event) {
              document.title = event.data;
            })
            // Give the frame a chance to load before sending message
            frame.addEventListener("load", function() { 
              frame.contentWindow.postMessage("ping");
            })
            frame.src = "/iframe/pong";
          </script>
        </body>
      </html>
      """
    brains.get "/iframe/pong", (req, res)->
      res.send """
      <script>
        window.addEventListener("message", function(event) {
          if (event.data == "ping")
            event.source.postMessage("pong " + event.origin);
        })
      </script>
      """
    brains.ready ->
      browser.visit "http://localhost:3003/iframe/ping", done

  it "should pass messages back and forth", ->
    assert.equal browser.document.title, "pong http://localhost:3003"

