{ assert, brains, Browser } = require("./helpers")


describe "Window", ->

  browser = null
  before (done)->
    browser = Browser.create()
    brains.ready(done)


  # -- Alert, confirm and popup; form when we let browsers handle our UI --

  describe ".alert", ->

    before ->
      brains.get "/window/alert", (req, res)->
        res.send """
        <html>
          <script>
            alert("Hi");
            alert("Me again");
          </script>
        </html>
        """

    before (done)->
      browser.onalert (message)->
        if message = "Me again"
          browser.window.first = true
      browser.visit("/window/alert", done)

    it "should record last alert show to user", ->
      browser.assert.prompted "Me again"
    it "should call onalert function with message", ->
      assert browser.window.first


  describe ".confirm", ->
    before ->
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

    before (done)->
      browser.onconfirm("continue?", true)
      browser.onconfirm (prompt)->
        return prompt == "more?"
      browser.visit("/window/confirm", done)

    it "should return canned response", ->
      assert browser.window.first
    it "should return response from function", ->
      assert browser.window.second
    it "should return false if no response/function", ->
      assert.equal browser.window.third, false
    it "should report prompted question", ->
      browser.assert.prompted "continue?"
      browser.assert.prompted "silent?"
      assert !browser.prompted("missing?")


  describe ".prompt", ->
    before ->
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

    before (done)->
      browser.onprompt("age", 31)
      browser.onprompt (message, def)->
        if message == "gender"
          return "unknown"
      browser.onprompt("location", false)
      browser.visit("/window/prompt", done)

    it "should return canned response", ->
      assert.equal browser.window.first, "31"
    it "should return response from function", ->
      assert.equal browser.window.second, "unknown"
    it "should return null if cancelled", ->
      assert.equal browser.window.third, null
    it "should return empty string if no response/function", ->
      assert.equal browser.window.fourth, ""
    it "should report prompts", ->
      browser.assert.prompted "age"
      browser.assert.prompted "gender"
      browser.assert.prompted "location"
      assert !browser.prompted("not asked")


  # -- This part deals with various windows properties ---

  describe ".title", ->
    before ->
      brains.get "/window/title", (req, res)->
        res.send """
        <html>
          <head>
            <title>Whatever</title>
          </head>
          <body>Hello World</body>
        </html>
        """

    before (done)->
      browser.visit("/window/title", done)

    it "should return the document's title", ->
      browser.assert.text "title", "Whatever"
    it "should set the document's title", ->
      browser.window.title = "Overwritten"
      assert.equal browser.window.title, browser.document.title


  describe ".screen", ->
    it "should have a screen object available", ->
      browser.assert.evaluate "screen.width", 1280
      browser.assert.evaluate "screen.height", 800
      browser.assert.evaluate "screen.left", 0
      browser.assert.evaluate "screen.top", 0
      browser.assert.evaluate "screen.availLeft", 0
      browser.assert.evaluate "screen.availTop", 0
      browser.assert.evaluate "screen.availWidth", 1280
      browser.assert.evaluate "screen.availHeight", 800
      browser.assert.evaluate "screen.colorDepth", 24
      browser.assert.evaluate "screen.pixelDepth", 24


  describe ".navigator", ->
    before ->
      brains.get "/window/navigator", (req, res)->
        res.send """
        <html>
          <head>
            <title>Whatever</title>
          </head>
          <body>Hello World</body>
        </html>
        """

    before (done)->
      browser.visit("/window/navigator", done)

    it "should exist", ->
      browser.assert.evaluate "navigator"
    it ".javaEnabled should be false", ->
      browser.assert.evaluate "navigator.javaEnabled()", false
    it ".language should be set to en-US", ->
      browser.assert.evaluate "navigator.language", "en-US"

  describe "atob", ->
    it "should decode base-64 string", ->
      window = browser.open()
      browser.assert.evaluate "atob('SGVsbG8sIHdvcmxk')", "Hello, world"

  describe "btoa", ->
    it "should encode base-64 string", ->
      window = browser.open()
      browser.assert.evaluate "btoa('Hello, world')", "SGVsbG8sIHdvcmxk"


  describe "onload", ->
    before ->
      brains.get "/windows/onload", (req, res)->
        res.send """
        <html>
          <head>
            <title>The Title!</title>
            <script type="text/javascript" language="javascript" charset="utf-8">
              var about = function (e) {
                var info = document.getElementById('das_link');
                info.innerHTML = (parseInt(info.innerHTML) + 1) + ' clicks here';
                e.preventDefault();
                return false;
              }
              window.onload = function () {
                var info = document.getElementById('das_link');
                info.addEventListener('click', about, false);
              }
            </script>
          </head>
          <body>
            <a id="das_link" href="/no_js.html">0 clicks here</a>
          </body>
        </html>
        """

    before (done)->
      browser.visit "/windows/onload", (error)=>
        browser.clickLink("#das_link", done)

    it "should fire when document is done loading", ->
      browser.assert.text "body", "1 clicks here"


  describe "resize", ->
    before ->
      @window = browser.open()
      assert.equal @window.innerWidth, 1024
      assert.equal @window.innerHeight, 768

    it "should change window dimensions", ->
      @window.resizeBy(-224, -168)
      assert.equal @window.innerWidth, 800
      assert.equal @window.innerHeight, 600


  after ->
    browser.destroy()
