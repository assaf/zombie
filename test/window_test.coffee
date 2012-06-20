{ assert, brains, Browser } = require("./helpers")


describe "Window", ->

  # -- Alert, confirm and popup; form when we let browsers handle our UI --
  
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
      brains.ready done

    before (done)->
      @browser = new Browser()
      @browser.onalert (message)=>
        if message = "Me again"
          @browser.window.first = true
      @browser.visit "/window/alert", done

    it "should record last alert show to user", ->
      assert @browser.prompted("Me again")
    it "should call onalert function with message", ->
      assert @browser.window.first


  describe ".confirm", ->
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
      brains.ready done

    before (done)->
      @browser = new Browser()
      @browser.onconfirm "continue?", true
      @browser.onconfirm (prompt)->
        return prompt == "more?"
      @browser.visit "/window/confirm", done

    it "should return canned response", ->
      assert @browser.window.first
    it "should return response from function", ->
      assert @browser.window.second
    it "should return false if no response/function", ->
      assert.equal @browser.window.third, false
    it "should report prompted question", ->
      assert @browser.prompted("continue?")
      assert @browser.prompted("silent?")
      assert !@browser.prompted("missing?")


  describe ".prompt", ->
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
      brains.ready done

    before (done)->
      @browser = new Browser()
      @browser.onprompt "age", 31
      @browser.onprompt (message, def)->
        if message == "gender"
          return "unknown"
      @browser.onprompt "location", false
      @browser.visit "/window/prompt", done

    it "should return canned response", ->
      assert.equal @browser.window.first, "31"
    it "should return response from function", ->
      assert.equal @browser.window.second, "unknown"
    it "should return null if cancelled", ->
      assert.equal @browser.window.third, null
    it "should return empty string if no response/function", ->
      assert.equal @browser.window.fourth, ""
    it "should report prompts", ->
      assert @browser.prompted("age")
      assert @browser.prompted("gender")
      assert @browser.prompted("location")
      assert !@browser.prompted("not asked")


  # -- This part deals with various windows properties ---

  describe ".title", ->
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
      brains.ready done

    before (done)->
      @browser = new Browser()
      @browser.visit "/window/title", done

    it "should return the document's title", ->
      assert.equal @browser.window.title, "Whatever"
    it "should set the document's title", ->
      @browser.window.title = "Overwritten"
      assert.equal @browser.window.title, @browser.document.title


  describe ".screen", ->
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
      brains.ready done

    before (done)->
      @browser = new Browser()
      @browser.visit "/window/screen", done

    it "should have a screen object available", ->
      assert /width=1280/.test(@browser.document.title)
      assert /height=800/.test(@browser.document.title)
      assert /left=0/.test(@browser.document.title)
      assert /top=0/.test(@browser.document.title)
      assert /availLeft=0/.test(@browser.document.title)
      assert /availTop=0/.test(@browser.document.title)
      assert /availWidth=1280/.test(@browser.document.title)
      assert /availHeight=800/.test(@browser.document.title)
      assert /colorDepth=24/.test(@browser.document.title)
      assert /pixelDepth=24/.test(@browser.document.title)


  describe ".navigator", ->
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
      brains.ready done

    before (done)->
      @browser = new Browser()
      @browser.visit "/window/navigator", done

    it "should exist", ->
      assert @browser.window.navigator
    it ".javaEnabled should be false", ->
      assert.equal @browser.window.navigator.javaEnabled(), false


  describe "atob", ->
    it "should decode base-64 string", ->
      browser = new Browser()
      window = browser.window
      assert.equal window.atob("SGVsbG8sIHdvcmxk"), "Hello, world"

  describe "btoa", ->
    it "should encode base-64 string", ->
      browser = new Browser()
      window = browser.window
      assert.equal window.btoa("Hello, world"), "SGVsbG8sIHdvcmxk"


  # -- Opening/closing/switching windows --

  describe "windows", ->

    before ->
      @browser = new Browser(name: "first")
      @browser.open(name: "second")
      @browser.open(name: "third")
      assert.equal @browser.windows.count, 3
      @windows = @browser.windows.all()

    describe "select", ->
      it "should pick window by name", ->
        @browser.windows.select("second")
        assert.equal @browser.window.name, "second"

      it "should pick window by index", ->
        @browser.windows.select(2)
        assert.equal @browser.window.name, "third"

      it "should be able to select specific window", ->
        @browser.windows.select(@windows[0])
        assert.equal @browser.window.name, "first"

      it "should fire onfocus event", (done)->
        @browser.windows.select @windows[0]
        @windows[1].addEventListener "focus", ->
          done()
          done = null # will be called multiple times from other tests
        @browser.windows.select @windows[1]

      it "should fire onblur event", (done)->
        @browser.windows.select @windows[0]
        @windows[0].addEventListener "blur", ->
          done()
          done = null # will be called multiple times from other tests
        @browser.windows.select @windows[2]


    describe "close", ->
      before ->
        @browser.windows.select @windows[0]
        @browser.windows.close(1)

      it "should discard one window", ->
        assert.equal @browser.windows.count, 2

      it "should discard specified window", ->
        assert.deepEqual @browser.windows.all().map((w)-> w.name), ["first", "third"]

      it "should select previous window", ->
        assert.equal @browser.window.name, "first"


      describe "close first", ->
        before ->
          @windows[2].addEventListener "focus", =>
            @onfocus = true
          @browser.windows.close()

        it "should close one window", ->
          assert.equal @browser.windows.count, 1

        it "should select next available window", ->
          assert.equal @browser.window.name, "third"

        it "should fire onfocus event", ->
          assert @onfocus


  describe "onload", ->
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
      @browser = new Browser()
      @browser.visit "/windows/onload", (error)=>
        @browser.clickLink "#das_link"
        done(error)

    it "should fire when document is done loading", ->
      assert.equal @browser.text("body"), "1 clicks here"


  describe "resize", ->
    it "should change window dimensions", ->
      browser = new Browser()
      assert.equal browser.window.innerWidth, 1024
      assert.equal browser.window.innerHeight, 768
      browser.window.resizeBy(-224, -168)
      assert.equal browser.window.innerWidth, 800
      assert.equal browser.window.innerHeight, 600
  
  describe "properties", ->
    before (done)->
      brains.get "/windows/propertiesA", (req, res)->
        res.send """
        <html>
          <head>
            <title>Properties A</title>
            <script type="text/javascript" language="javascript" charset="utf-8">
              window.magic = "A";
              window.propa = "A";
            </script>
          </head>
          <body>
          </body>
        </html>
        """
      brains.get "/windows/propertiesB", (req, res)->
        res.send """
        <html>
          <head>
            <title>Properties B</title>
            <script type="text/javascript" language="javascript" charset="utf-8">
              window.magic = "B";
              window.propb = "B";
            </script>
          </head>
          <body>
          </body>
        </html>
        """
      brains.ready done
      
    before (done)->
      @browser = browser = new Browser()
      @browser.visit "/windows/propertiesA", (error) ->
        browser.window.crossover = "crossover"
        browser.visit "/windows/propertiesB", (error) ->
          done(error)

    describe "go forward", ->
      it "should not carry from one page to the next", ->
        assert !@browser.window.crossover
      it "should have window.magic set to 'B'", ->
        assert.equal @browser.window.magic, "B"
      it "should have window.propb set to 'B'", ->
        assert.equal @browser.window.propb, "B"
      it "should have window.propa undefined", ->
        assert !@browser.window.propa
    
    describe "go backward", ->
      before (done)->
        @browser.back (error) ->
          done(error)
      
      it "should restore crossover", ->
        assert.equal @browser.window.crossover, "crossover"
      it "should have window.magic set to 'A", ->
        assert.equal @browser.window.magic, "A"
      it "should have window.propa set to 'A'", ->
        assert.equal @browser.window.propa, "A"
      it "should have window.propb undefined", ->
        assert !@browser.window.propb

