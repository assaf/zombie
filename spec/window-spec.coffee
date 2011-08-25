require "./helpers"
{ vows: vows, assert: assert, zombie: zombie, brains: brains } = require("vows")
Browser = zombie.Browser


vows.describe("Window").addBatch(
  ".title":
    topic: ->
      brains.get "/title", (req, res)-> res.send """
        <html>
          <head>
            <title>Whatever</title>
          </head>
          <body>Hello World</body>
        </html>
        """
      browser = new Browser
      browser.wants "http://localhost:3003/title", @callback
    "should return the document's title": (browser)-> assert.equal browser.window.title, "Whatever"
    "should set the document's title": (browser)->
      browser.window.title = "Overwritten"
      assert.equal browser.window.title, browser.document.title

  ".alert":
    topic: ->
      brains.get "/alert", (req, res)-> res.send """
        <script>
          alert("Hi");
          alert("Me again");
        </script>
        """
      browser = new Browser
      browser.onalert (message)-> browser.window.first = true if message = "Me again"
      browser.wants "http://localhost:3003/alert", @callback
    "should record last alert show to user": (browser)-> assert.ok browser.prompted("Me again")
    "should call onalert function with message": (browser)-> assert.ok browser.window.first

  ".confirm":
    topic: ->
      brains.get "/confirm", (req, res)-> res.send """
        <script>
          window.first = confirm("continue?");
          window.second = confirm("more?");
          window.third = confirm("silent?");
        </script>
        """
      browser = new Browser
      browser.onconfirm "continue?", true
      browser.onconfirm (prompt)-> true if prompt == "more?"
      browser.wants "http://localhost:3003/confirm", @callback
    "should return canned response": (browser)-> assert.ok browser.window.first
    "should return response from function": (browser)-> assert.ok browser.window.second
    "should return false if no response/function": (browser)-> assert.equal browser.window.third, false
    "should report prompted question": (browser)->
      assert.ok browser.prompted("continue?")
      assert.ok browser.prompted("silent?")
      assert.ok !browser.prompted("missing?")

  ".prompt":
    topic: ->
      brains.get "/prompt", (req, res)-> res.send """
        <script>
          window.first = prompt("age");
          window.second = prompt("gender");
          window.third = prompt("location");
          window.fourth = prompt("weight");
        </script>
        """
      browser = new Browser
      browser.onprompt "age", 31
      browser.onprompt (message, def)-> "unknown" if message == "gender"
      browser.onprompt "location", false
      browser.wants "http://localhost:3003/prompt", @callback
    "should return canned response": (browser)-> assert.equal browser.window.first, "31"
    "should return response from function": (browser)-> assert.equal browser.window.second, "unknown"
    "should return null if cancelled": (browser)-> assert.isNull browser.window.third
    "should return empty string if no response/function": (browser)-> assert.equal browser.window.fourth, ""
    "should report prompts": (browser)->
      assert.ok browser.prompted("age")
      assert.ok browser.prompted("gender")
      assert.ok browser.prompted("location")
      assert.ok !browser.prompted("not asked")

  ".screen":
    topic: ->
      brains.get "/screen", (req, res)-> res.send """
        <html>
          <script>
            var props = [];

            for (key in window.screen) {
              props.push(key + "=" + window.screen[key]);
            }

            document.title = props.join(", ");
          </script>
        </html>
        """
      browser = new Browser
      browser.wants "http://localhost:3003/screen", @callback
    "should have a screen object available": (browser)->
      assert.match browser.document.title, /width=1280/
      assert.match browser.document.title, /height=800/
      assert.match browser.document.title, /left=0/
      assert.match browser.document.title, /top=0/
      assert.match browser.document.title, /availLeft=0/
      assert.match browser.document.title, /availTop=0/
      assert.match browser.document.title, /availWidth=1280/
      assert.match browser.document.title, /availHeight=800/
      assert.match browser.document.title, /colorDepth=24/
      assert.match browser.document.title, /pixelDepth=24/

  ".navigator":
    topic: ->
      brains.get "/navigator", (req, res)-> res.send """
        <html>
          <head>
            <title>Whatever</title>
          </head>
          <body>Hello World</body>
        </html>
        """
      browser = new Browser
      browser.wants "http://localhost:3003/navigator", @callback
    "should exist": (browser)-> assert.isNotNull browser.window.navigator
    ".javaEnabled should be false": (browser)-> assert.equal browser.window.navigator.javaEnabled(), false
).export(module)
