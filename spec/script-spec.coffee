require "./helpers"
{ vows: vows, assert: assert, zombie: zombie, brains: brains } = require("vows")


brains.get "/scripted", (req, res)-> res.send """
  <html>
    <head>
      <title>Whatever</title>
      <script src="/jquery.js"></script>
    </head>
    <body>Hello World</body>
    <script>
      document.title = "Nice";
      $(function() { $("title").text("Awesome") })
    </script>
  </html>
  """

brains.get "/living", (req, res)-> res.send """
  <html>
    <head>
      <script src="/jquery.js"></script>
      <script src="/sammy.js"></script>
      <script src="/app.js"></script>
    </head>
    <body>
      <div id="main">
        <a href="/dead">Kill</a>
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

brains.get "/dead", (req, res)-> res.send """
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

brains.get "/context", (req, res)-> res.send """
  <script>var foo = 1;</script>
  <script>foo = foo + 1;</script>
  <script>document.title = foo;</script>
  """


vows.describe("Scripts").addBatch(
  "script context":
    zombie.wants "http://localhost:3003/context"
      "should be shared by all scripts": (browser)-> assert.equal browser.text("title"), "2"

  "adding script using document.write":
    zombie.wants "http://localhost:3003/script/write"
      "should run script": (browser)-> assert.equal browser.document.title, "Script document.write"
  "adding script using appendChild":
    zombie.wants "http://localhost:3003/script/append"
      "should run script": (browser)-> assert.equal browser.document.title, "Script appendChild"

  "run without scripts":
    topic: ->
      browser = new zombie.Browser(runScripts: false)
      browser.wants "http://localhost:3003/scripted", @callback
    "should load document from server": (browser)-> assert.match browser.html(), /<body>Hello World/
    "should not load external scripts": (browser)-> assert.isUndefined browser.window.jQuery
    "should not run scripts": (browser)-> assert.equal browser.document.title, "Whatever"

  "run app":
    zombie.wants "http://localhost:3003/living"
      "should execute route": (browser)-> assert.equal browser.document.title, "The Living"
      "should change location": (browser)-> assert.equal browser.location, "http://localhost:3003/living#/"
      "move around":
        topic: (browser)->
          browser.window.location.hash = "/dead"
          browser.wait @callback
        "should execute route": (browser)-> assert.equal browser.text("#main"), "The Living Dead"
        "should change location": (browser)-> assert.equal browser.location, "http://localhost:3003/living#/dead"

  "live events":
    zombie.wants "http://localhost:3003/living"
      topic: (browser)->
        browser.fill("Email", "armbiter@zombies").fill("Password", "br41nz").
          pressButton "Sign Me Up", @callback
      "should change location": (browser)-> assert.equal browser.location, "http://localhost:3003/living#/"
      "should process event": (browser)-> assert.equal browser.document.title, "Signed up"

).export(module)
