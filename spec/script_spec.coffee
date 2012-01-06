{ Vows, assert, brains, Browser } = require("./helpers")


Vows.describe("Scripts").addBatch

  "basic":
    topic: ->
      brains.get "/script/living", (req, res)->
        res.send """
        <html>
          <head>
            <script src="/jquery.js"></script>
            <script src="/sammy.js"></script>
            <script src="/app.js"></script>
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

      brains.get "/app.js", (req, res)->
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

    "run app":
      Browser.wants "http://localhost:3003/script/living"
        "should execute route": (browser)->
          assert.equal browser.document.title, "The Living"
        "should change location": (browser)->
          assert.equal browser.location.href, "http://localhost:3003/script/living#/"
        "move around":
          topic: (browser)->
            browser.visit browser.location.href + "dead", @callback
          "should execute route": (browser)->
            assert.equal browser.text("#main"), "The Living Dead"
          "should change location": (browser)->
            assert.equal browser.location.href, "http://localhost:3003/script/living#/dead"

    "live events":
      Browser.wants "http://localhost:3003/script/living"
        topic: (browser)->
          browser.fill "Email", "armbiter@zombies"
          browser.fill "Password", "br41nz"
          browser.pressButton "Sign Me Up"
          browser.wait 500, @callback
        "should change location": (browser)->
          assert.equal browser.location.href, "http://localhost:3003/script/living#/"
        "should process event": (browser)->
          assert.equal browser.document.title, "Signed up"

    "evaluate":
      Browser.wants "http://localhost:3003/script/living"
        topic: (browser)->
          browser.evaluate "document.title"
        "should evaluate in context and return value": (title)->
          assert.equal title, "The Living"

.addBatch

  "evaluating":
    "context":
      topic: ->
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
        browser = new Browser
        browser.wants "http://localhost:3003/script/context", @callback
      "should be shared by all scripts": (browser)->
        assert.equal browser.text("title"), "4"

    "window":
      topic: ->
        brains.get "/script/window", (req, res)->
          res.send """
          <html>
            <script>document.title = [window == this, this == window.window, this == top, top == window.top, this == parent, top == window.parent].join(',')</script>
          </html>
          """
        browser = new Browser
        browser.wants "http://localhost:3003/script/window", @callback
      "should be the same as this, top and parent": (browser)->
        assert.equal browser.text("title"), "true,true,true,true,true,true"

    "global and function":
      topic: ->
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
        browser = new Browser
        browser.wants "http://localhost:3003/script/global_and_fn", @callback
      "should not fail with an error": (browser)->
        assert.isEmpty browser.errors
      "should set global variable": (browser)->
        assert.equal browser.text("title"), "foo"


  "order":
    topic: ->
      brains.get "/script/order", (req, res)->
        res.send """
        <html>
          <head>
            <title>Zero</title>
            <script src="/script/order.js"></script>
          </head>
          <body>
            <script>
            document.title = document.title + "Two";</script>
          </body>
        </html>
        """
      brains.get "/script/order.js", (req, res)->
        res.send "document.title = document.title + 'One'"
      browser = new Browser
      browser.wants "http://localhost:3003/script/order", @callback
    "should run scripts in order regardless of source": (browser)->
      assert.equal browser.text("title"), "ZeroOneTwo"


  "eval":
    topic: ->
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
              console.log(qux)

              document.title = eval('e_foo + bar + baz + qux');
            })();
          </script>
        </html>
        """
      browser = new Browser
      browser.wants "http://localhost:3003/script/eval", @callback
    "should evaluate in global scope": (browser)->
      assert.equal browser.document.title, "OneTwoThreeFour"


.addBatch
  
  "failing":
    "incomplete":
      topic: ->
        brains.get "/script/incomplete", (req, res)->
          res.send "<script>1+</script>"
        browser = new Browser
        browser.wants "http://localhost:3003/script/incomplete", @callback
      "should propagate error to window": (browser)->
        assert.equal browser.error.message, "Unexpected end of input"

    "error":
      topic: ->
        brains.get "/script/error", (req, res)->
          res.send "<script>(function(foo) { foo.bar })()</script>"
        browser = new Browser
        browser.wants "http://localhost:3003/script/error", @callback
      "should propagate error to window": (browser)->
        assert.equal browser.error.message, "Cannot read property 'bar' of undefined"


.addBatch

  "loading":
    "with entities":
      topic: ->
        brains.get "/script/split", (req, res)->
          res.send """
          <html>
            <script>foo = 1 < 2 ? 1 : 2; '&'; document.title = foo</script>
          </html>
          """
        browser = new Browser
        browser.wants "http://localhost:3003/script/split", @callback
      "should run full script": (browser)->
        assert.equal browser.text("title"), "1"

    ###
    # NOTE: htmlparser can't deal with CDATA sections
    "with CDATA":
      topic: ->
        brains.get "/script/cdata", (req, res)-> res.send """
          <html>
            <script>foo = 2; <![CDATA[ document.title ]]> = foo</script>
          </html>
          """
        browser = new Browser
        browser.wants "http://localhost:3003/script/cdata", @callback
      "should run full script": (browser)-> assert.equal browser.text("title"), "2"
    ###

    # NOTE: htmlparser can't deal with document.write.
    ###
    "using document.write":
      topic: ->
        brains.get "/script/write", (req, res)-> res.send """
          <html>
            <head>
              <script>document.write(unescape(\'%3Cscript src="/jquery.js"%3E%3C/script%3E\'));</script>
            </head>
            <body>
              <script>
                $(function() { document.title = "Script document.write" });
              </script>
            </body>
          </html>
          """
        browser = new Browser
        browser.wants "http://localhost:3003/script/write", @callback
      "should run script": (browser)-> assert.equal browser.document.title, "Script document.write"
    ###

    "using appendChild":
      topic: ->
        brains.get "/script/append", (req, res)->
          res.send """
          <html>
            <head>
              <script>
                var s = document.createElement('script'); s.type = 'text/javascript'; s.async = true;
                s.src = '/jquery.js';
                (document.getElementsByTagName('head')[0] || document.getElementsByTagName('body')[0]).appendChild(s);
              </script>
            </head>
            <body>
              <script>
                $(function() { document.title = "Script appendChild" });
              </script>
            </body>
          </html>
          """
        browser = new Browser
        browser.wants "http://localhost:3003/script/append", @callback
      "should run script": (browser)->
        assert.equal browser.document.title, "Script appendChild"

  "scripts disabled":
    topic: ->
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
      browser = new Browser(runScripts: false)
      browser.wants "http://localhost:3003/script/order", @callback
    "should not run scripts": (browser)->
      assert.equal browser.document.title, "Zero"


  ###
.addBatch

  "new Image":
    Browser.wants "http://localhost:3003/script/living"
      "should construct an img tag": (browser)-> assert.equal domToHtml(browser.evaluate("new Image")), "<img>\r\n"
      "should construct an img tag with width and height": (browser)->
        assert.equal domToHtml(browser.evaluate("new Image(1, 1)")), "<img width=\"1\" height=\"1\">\r\n"
  ###

      
.export(module)
