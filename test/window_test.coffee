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
        browser.visit "/window/title", done

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
        browser.visit "/window/alert", done

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
        browser.visit "/window/confirm", done

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
        browser.visit "/window/prompt", done

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
        browser.visit "/window/screen", done

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
        browser.visit "/window/navigator", done

    it "should exist", ->
      assert browser.window.navigator
    it ".javaEnabled should be false", ->
      assert.equal browser.window.navigator.javaEnabled(), false


  describe "windows", ->
    browser = new Browser(name: "first")

    before ->
      browser.open(name: "second")
      browser.open(name: "third")
      assert.equal browser.windows.count, 3

    describe "select", ->
      it "should pick window by name", ->
        browser.windows.select("second")
        assert.equal browser.window.name, "second"

      it "should pick window by index", ->
        browser.windows.select(2)
        assert.equal browser.window.name, "third"

      it "should be able to select specific window", ->
        browser.windows.select(browser.windows.all()[0])
        assert.equal browser.window.name, "first"

    describe "close", ->
      before ->
        browser.windows.close(1)

      it "should discard one window", ->
        assert.equal browser.windows.count, 2

      it "should discard specified window", ->
        assert.deepEqual browser.windows.all().map((w)-> w.name), ["first", "third"]

      it "should select previous window", ->
        assert.equal browser.window.name, "first"

      describe "close first", ->
        before ->
          browser.windows.close()
          assert.equal browser.windows.count, 1

        it "should select next available window", ->
          assert.equal browser.window.name, "third"


  describe "onload", ->
    browser = new Browser()

    before (done)->
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
      brains.ready done

    before (done)->
      browser.visit("/windows/onload")
        .then ->
          browser.clickLink "#das_link"
        .then done

    it "should fire when document is done loading", ->
      assert.equal browser.text("body"), "1 clicks here"

