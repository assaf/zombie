require "./helpers"
{ vows: vows, assert: assert, zombie: zombie, brains: brains } = require("vows")

brains.get "/script/context", (req, res)-> res.send """
  <script>var foo = 1</script>
  <script>window.foo = foo + 1</script>
  <script>document.title = this.foo</script>
  <script>setTimeout(function() {
    document.title = foo + window.foo
  })</script>
  """

brains.get "/script/order", (req, res)-> res.send """
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
brains.get "/script/order.js", (req, res)-> res.send "document.title = document.title + 'One'";

brains.get "/script/dead", (req, res)-> res.send """
  <html>
    <head>
      <script src="/jquery.js"></script>
    </head>
    <body>
      <script>
        $(function() { document.title = "The Dead" });
      </script>
    </body>
  </html>
  """

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

brains.get "/script/append", (req, res)-> res.send """
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

brains.get "/script/living", (req, res)-> res.send """
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

brains.get "/script/ssl", (req, res)-> res.send """
  <html>
    <head>
      <script>
        function jsonp(response) {
          document.title = response[2].id;
        }
      </script>

      <script src="https://api.mercadolibre.com/sites/MLA?callback=jsonp"></script>
    </head>
    <body>

    </body>
  </html>
  """

brains.get "/app.js", (req, res)-> res.send """
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


vows.describe("Scripts").addBatch(
  "script context":
    zombie.wants "http://localhost:3003/script/context"
      "should be shared by all scripts": (browser)-> assert.equal browser.text("title"), "4"

  "script order":
    zombie.wants "http://localhost:3003/script/order"
      "should run scripts in order regardless of source": (browser)-> assert.equal browser.text("title"), "ZeroOneTwo"

  "adding script using document.write":
    zombie.wants "http://localhost:3003/script/write"
      "should run script": (browser)-> assert.equal browser.document.title, "Script document.write"
  "adding script using appendChild":
    zombie.wants "http://localhost:3003/script/append"
      "should run script": (browser)-> assert.equal browser.document.title, "Script appendChild"

  "run without scripts":
    topic: ->
      browser = new zombie.Browser(runScripts: false)
      browser.wants "http://localhost:3003/script/order", @callback
    "should not run scripts": (browser)-> assert.equal browser.document.title, "Zero"

  "run app":
    zombie.wants "http://localhost:3003/script/living"
      "should execute route": (browser)-> assert.equal browser.document.title, "The Living"
      "should change location": (browser)-> assert.equal browser.location.href, "http://localhost:3003/script/living#/"
      "move around":
        topic: (browser)->
          browser.visit browser.location.href + "dead", @callback
        "should execute route": (browser)-> assert.equal browser.text("#main"), "The Living Dead"
        "should change location": (browser)-> assert.equal browser.location.href, "http://localhost:3003/script/living#/dead"

  "live events":
    zombie.wants "http://localhost:3003/script/living"
      topic: (browser)->
        browser.fill("Email", "armbiter@zombies").fill("Password", "br41nz").
          pressButton "Sign Me Up", @callback
      "should change location": (browser)-> assert.equal browser.location.href, "http://localhost:3003/script/living#/"
      "should process event": (browser)-> assert.equal browser.document.title, "Signed up"

  "evaluate":
    zombie.wants "http://localhost:3003/script/living"
      topic: (browser)->
        browser.evaluate "document.title"
      "should evaluate in context and return value": (title)-> assert.equal title, "The Living"

  ###
  "SSL":
    zombie.wants "http://localhost:3003/script/ssl"
      "should load scripts over SSL": (browser)->
        assert.equal browser.window.title, "MLA"
  ###

).export(module)
