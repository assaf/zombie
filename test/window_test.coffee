{ assert, brains, Browser } = require("./helpers")


describe "Window", ->

  describe ".title", ->
    browser = new Browser()

    before (done)->
      brains.get "/window/title", (req, res)->
        res.send """
        <html>
          <head>
            <title>Whatever</title>
          </head>
          <body>Hello World</body>
        </html>
        """
      brains.ready ->
        browser.visit "http://localhost:3003/window/title", done

    it "should return the document's title", ->
      assert.equal browser.window.title, "Whatever"
    it "should set the document's title", ->
      browser.window.title = "Overwritten"
      assert.equal browser.window.title, browser.document.title


  describe ".alert", ->
    browser = new Browser()

    before (done)->
      brains.get "/window/alert", (req, res)->
        res.send """
        <html>
          <script>
            alert("Hi");
            alert("Me again");
          </script>
        </html>
        """
      browser.onalert (message)->
        if message = "Me again"
          browser.window.first = true
      brains.ready ->
        browser.visit "http://localhost:3003/window/alert", done

    it "should record last alert show to user", ->
      assert browser.prompted("Me again")
    it "should call onalert function with message", ->
      assert browser.window.first


  describe ".confirm", ->
    browser = new Browser()

    before (done)->
      brains.get "/window/confirm", (req, res)->
        res.send """
        <html>
          <script>
            window.first = confirm("continue?");
            window.second = confirm("more?");
            window.third = confirm("silent?");
          </script>
        </html>
        """
      browser.onconfirm "continue?", true
      browser.onconfirm (prompt)->
        return prompt == "more?"
      brains.ready ->
        browser.visit "http://localhost:3003/window/confirm", done

    it "should return canned response", ->
      assert browser.window.first
    it "should return response from function", ->
      assert browser.window.second
    it "should return false if no response/function", ->
      assert.equal browser.window.third, false
    it "should report prompted question", ->
      assert browser.prompted("continue?")
      assert browser.prompted("silent?")
      assert !browser.prompted("missing?")


  describe ".prompt", ->
    browser = new Browser()

    before (done)->
      brains.get "/window/prompt", (req, res)->
        res.send """
        <html>
          <script>
            window.first = prompt("age");
            window.second = prompt("gender");
            window.third = prompt("location");
            window.fourth = prompt("weight");
          </script>
        </html>
        """
      browser.onprompt "age", 31
      browser.onprompt (message, def)->
        if message == "gender"
          return "unknown"
      browser.onprompt "location", false
      brains.ready ->
        browser.visit "http://localhost:3003/window/prompt", done

    it "should return canned response", ->
      assert.equal browser.window.first, "31"
    it "should return response from function", ->
      assert.equal browser.window.second, "unknown"
    it "should return null if cancelled", ->
      assert.equal browser.window.third, null
    it "should return empty string if no response/function", ->
      assert.equal browser.window.fourth, ""
    it "should report prompts", ->
      assert browser.prompted("age")
      assert browser.prompted("gender")
      assert browser.prompted("location")
      assert !browser.prompted("not asked")


  describe ".screen", ->
    browser = new Browser()

    before (done)->
      brains.get "/window/screen", (req, res)->
        res.send """
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
      brains.ready ->
        browser.visit "http://localhost:3003/window/screen", done

    it "should have a screen object available", ->
      assert /width=1280/.test(browser.document.title)
      assert /height=800/.test(browser.document.title)
      assert /left=0/.test(browser.document.title)
      assert /top=0/.test(browser.document.title)
      assert /availLeft=0/.test(browser.document.title)
      assert /availTop=0/.test(browser.document.title)
      assert /availWidth=1280/.test(browser.document.title)
      assert /availHeight=800/.test(browser.document.title)
      assert /colorDepth=24/.test(browser.document.title)
      assert /pixelDepth=24/.test(browser.document.title)


  describe ".navigator", ->
    browser = new Browser()

    before (done)->
      brains.get "/window/navigator", (req, res)->
        res.send """
        <html>
          <head>
            <title>Whatever</title>
          </head>
          <body>Hello World</body>
        </html>
        """
      brains.ready ->
        browser.visit "http://localhost:3003/window/navigator", done

    it "should exist", ->
      assert browser.window.navigator
    it ".javaEnabled should be false", ->
      assert.equal browser.window.navigator.javaEnabled(), false

