{ assert, brains, Browser } = require("./helpers")


describe "Scripts", ->
  browser = null

  before (done)->
    browser = Browser.create()
    brains.ready(done)

  describe "basic", ->
    before ->
      brains.get "/script/living", (req, res)->
        res.send """
        <html>
          <head>
            <script src="/jquery.js"></script>
            <script src="/sammy.js"></script>
            <script src="/script/living/app.js"></script>
          </head>
          <body>
            <div id="main">
              <a href="/script/dead">Kill</a>
              <form action="#/dead" method="post">
                <label>Email <input type="text" name="email"></label>
                <label>Password <input type="password" name="password"></label>
                <button>Sign Me Up</button>
              </form>
            </div>
            <div class="now">Walking Aimlessly</div>
          </body>
        </html>
        """

      brains.get "/script/living/app.js", (req, res)->
        res.send """
        Sammy("#main", function(app) {
          app.get("#/", function(context) {
            document.title = "The Living";
          });
          app.get("#/dead", function(context) {
            context.swap("The Living Dead");
          });
          app.post("#/dead", function(context) {
            document.title = "Signed up";
          });
        });
        $(function() { Sammy("#main").run("#/") });
        """

    describe "run app", ->
      before (done)->
        browser.visit("/script/living", done)

      it "should execute route", ->
        browser.assert.text "title", "The Living"
      it "should change location", ->
        browser.assert.url "http://localhost:3003/script/living#/"

      describe "move around", ->
        before (done)->
          browser.visit("/script/living#/dead")
          hashChanged = (window)->
            return browser.text("#main") == "The Living Dead"
          browser.wait(function: hashChanged, done)

        it "should execute route", ->
          browser.assert.text "#main", "The Living Dead"
        it "should change location", ->
          browser.assert.url "http://localhost:3003/script/living#/dead"


    describe "live events", ->
      before (done)->
        browser.visit "/script/living/", ->
          browser
            .fill("Email", "armbiter@zombies")
            .fill("Password", "br41nz")
            .pressButton("Sign Me Up", done)

      it "should change location", ->
        browser.assert.url "http://localhost:3003/script/living/#/"
      it "should process event", ->
        browser.assert.text "title", "Signed up"


    describe "evaluate", ->
      before (done)->
        browser.visit("/script/living/", done)

      it "should evaluate in context and return value", ->
        title = browser.evaluate("document.title")
        assert.equal title, "The Living"


  describe "evaluating", ->

    describe "context", ->
      before (done)->
        brains.get "/script/context", (req, res)->
          res.send """
          <html>
            <script>var foo = 1</script>
            <script>window.foo = foo + 1</script>
            <script>document.title = this.foo</script>
            <script>
            setTimeout(function() {
              document.title = foo + window.foo
            });</script>
          </html>
          """
        browser.visit("/script/context", done)

      it "should be shared by all scripts", ->
        browser.assert.text "title", "4"


    describe "window", ->
      before (done)->
        brains.get "/script/window", (req, res)->
          res.send """
          <html>
            <script>document.title = [window == this,
                                      this == window.window,
                                      this == top,
                                      top == window.top,
                                      this == parent,
                                      top == parent].join(',')</script>
          </html>
          """
        browser.visit("/script/window", done)

      it "should be the same as this, top and parent", ->
        browser.assert.text "title", "true,true,true,true,true,true"


    describe "global and function", ->
      before (done)->
        brains.get "/script/global_and_fn", (req, res)->
          res.send """
          <html>
            <script>
              var foo;
              (function() {
                if (!foo)
                  foo = "foo";
              })()
              document.title = foo;
            </script>
          </html>
          """
        browser.visit("/script/global_and_fn", done)

      it "should not fail with an error", ->
        assert.equal browser.errors.length, 0
      it "should set global variable", ->
        browser.assert.text "title", "foo"


  describe "order", ->
    before (done)->
      brains.get "/script/order", (req, res)->
        res.send """
        <html>
          <head>
            <title>Zero</title>
            <script src="/script/order.js"></script>
          </head>
          <body>
            <script>
              document.title = document.title + "Two";
            </script>
          </body>
        </html>
        """
      brains.get "/script/order.js", (req, res)->
        res.send("document.title = document.title + 'One'")
      browser.visit("/script/order", done)

    it "should run scripts in order regardless of source", ->
      browser.assert.text "title", "ZeroOneTwo"


  describe "eval", ->
    before (done)->
      brains.get "/script/eval", (req, res)->
        res.send """
        <html>
          <script>
            var foo = "One";
            (function() {
              var bar = "Two"; // standard eval sees this
              var e = eval; // this 'eval' only sees global scope
              try {
                var baz = e("bar");
              } catch (ex) {
                var baz = "Three";
              }
              // In spite of local variable, global scope eval finds global foo
              var foo = "NotOne";
              var e_foo = e("foo");
              var qux = window.eval.call(window, "foo");

              document.title = eval('e_foo + bar + baz + qux');
            })();
          </script>
        </html>
        """
      browser.visit("/script/eval", done)

    it "should evaluate in global scope", ->
      browser.assert.text "title", "OneTwoThreeOne"


  describe "failing", ->
    describe "incomplete", ->
      before (done)->
        brains.get "/script/incomplete", (req, res)->
          res.send """
            <html>
              <script>1+</script>
            </html>
          """
        browser.visit("/script/incomplete")
        browser.wait (@error)=>
          done()

      it "should pass error to callback", ->
        assert.equal @error.message, "Unexpected end of input"

      it "should propagate error to window", ->
        assert.equal browser.error.message, "Unexpected end of input"

    describe "error", ->
      before (done)->
        brains.get "/script/error", (req, res)->
          res.send """
            <html>
              <script>(function(foo) { foo.bar })()</script>
            </html>
          """
        browser.visit("/script/error")
        browser.wait (@error)=>
          done()

      it "should pass error to callback", ->
        assert.equal @error.message, "Cannot read property 'bar' of undefined"

      it "should propagate error to window", ->
        assert.equal browser.error.message, "Cannot read property 'bar' of undefined"


  describe "loading", ->

    describe "with entities", ->
      before (done)->
        brains.get "/script/split", (req, res)->
          res.send """
          <html>
            <script>foo = 1 < 2 ? 1 : 2; '&'; document.title = foo</script>
          </html>
          """
        browser.visit("/script/split", done)

      it "should run full script", ->
        browser.assert.text "title", "1"


    describe.skip "with CDATA", ->
      before (done)->
        brains.get "/script/cdata", (req, res)-> res.send """
          <html>
            <script><![CDATA[ document.title = 2 ]]></script>
          </html>
          """
        browser.visit("/script/cdata", done)

      it "should run full script", ->
        assert.equal browser.text("title"), "2"


    describe "using document.write", ->
      before (done)->
        brains.get "/script/write", (req, res)-> res.send """
          <html>
            <body>
            <script>document.write(unescape(\'%3Cscript %3Edocument.title = document.title + ".write"%3C/script%3E\'));</script>
            <script>
              document.title = document.title + "document";
            </script>
            </body>
          </html>
          """
        browser.visit("/script/write", done)

      it "should run script", ->
        browser.assert.text "title", "document.write"


    describe "using appendChild", ->
      before (done)->
        brains.get "/script/append", (req, res)->
          res.send """
          <html>
            <head>
              <script>
                var s = document.createElement('script'); s.type = 'text/javascript'; s.async = true;
                s.src = '/script/append.js';
                (document.getElementsByTagName('head')[0] || document.getElementsByTagName('body')[0]).appendChild(s);
              </script>
            </head>
            <body>
              <script>
                document.title = document.title + "element.";
              </script>
            </body>
          </html>
          """
        brains.get "/script/append.js", (req, res)->
          res.send("document.title = document.title + \"appendChild\"")
        browser.visit "/script/append", done

      it "should run script", ->
        browser.assert.text "title", "element.appendChild"


  describe "scripts disabled", ->
    before (done)->
      brains.get "/script/no-scripts", (req, res)->
        res.send """
        <html>
          <head>
            <title>Zero</title>
            <script src="/script/no-scripts.js"></script>
          </head>
          <body>
            <script>
            document.title = document.title + "Two";</script>
          </body>
        </html>
        """
      brains.get "/script/no-scripts.js", (req, res)->
        res.send "document.title = document.title + 'One'"
      browser.features = "no-scripts"
      browser.visit("/script/order", done)

    it "should not run scripts", ->
      browser.assert.text "title", "Zero"

    after ->
      browser.features = "scripts"

  describe "script attributes", ->
    before (done)->
      brains.get "/script/inline", (req, res)->
        res.send """
        <html>
          <head>
            <title></title>
            <script>var bar = null;</script>
          </head>
          <body>
          </body>
        </html>
        """
      browser.visit('/script/inline', done)

    it "should have a valid src", ->
      nodes = browser.queryAll("script")
      assert.equal nodes[0].src, ""

  describe "file:// uri scheme", ->
    before (done)->
      browser.visit("file://#{__dirname}/data/file_scheme.html", done)

    it "should run scripts with file url src", ->
      browser.assert.text "title", "file://"

  describe "file:// uri with encoded spaces", ->
    before (done)->
      browser.visit("file://#{__dirname}/data/dir%20with%20spaces/file_scheme%20with%20spaces.html", done)

    it "should run scripts with file url src containing encoded spaces", ->
      browser.assert.text "title", "file://"

  describe "javascript: URL", ->
    describe "existing page", ->
      before (done)->
        browser.visit "/script/living", ->
          browser.visit("javascript:window.message = 'hi'", done)

      it "should evaluate script in context of window", ->
        browser.assert.evaluate "message", "hi"

    describe "blank page", ->
      before (done)->
        browser.tabs.close()
        browser.visit("javascript:window.message = 'hi'", done)

      it "should evaluate script in context of window", ->
        browser.assert.evaluate "message", "hi"

  describe "new Image", ->
    it "should construct an img tag", ->
      browser.assert.evaluate "new Image().tagName", "IMG"
    it "should construct an img tag with width and height", ->
      browser.assert.evaluate "new Image(1, 1).height", 1


  describe "Event", ->
    it "should be available in global context", ->
      browser.assert.evaluate "Event"

  describe "on- event handler (string)", ->
    before (done)->
      brains.get "/script/on-event/string", (req, res)->
        res.send """
          <form onsubmit="document.title = event.eventType; return false">
            <button>Submit</button>
          </form>
        """
      brains.ready done

    before (done)->
      browser.visit("/script/on-event/string")
        .then =>
          browser.pressButton("Submit")
        .then(done, done)

    it "should prevent default handling by returning false", ->
      browser.assert.url "http://localhost:3003/script/on-event/string"

    it "should have access to window.event", ->
      browser.assert.text "title", "HTMLEvents"


  describe "on- event handler (function)", ->
    before (done)->
      brains.get "/script/on-event/function", (req, res)->
        res.send """
          <form>
            <button>Submit</button>
          </form>
          <script>
            document.getElementsByTagName("form")[0].onsubmit = function(event) {
              document.title = event.eventType;
              event.preventDefault();
            }
          </script>
        """
      brains.ready done

    before (done)->
      browser.visit("/script/on-event/function")
        .then =>
          browser.pressButton("Submit")
        .then(done, done)

    it "should prevent default handling by returning false", ->
      browser.assert.url "http://localhost:3003/script/on-event/function"

    it "should have access to window.event", ->
      browser.assert.text "title", "HTMLEvents"


  describe "JSON parsing", ->
    it "should respect prototypes", ->
      browser.assert.evaluate """
        Array.prototype.method = function() {};
        JSON.parse("[0, 1]").method;
      """


  after ->
    browser.destroy()
