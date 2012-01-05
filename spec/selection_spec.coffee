{ Vows, assert, brains, Browser } = require("./helpers")


Vows.describe("Selection").addBatch

  "content selection":
    topic: ->
      brains.get "/browser/walking", (req, res)->
        res.send """
        <html>
          <head>
            <script src="/jquery.js"></script>
            <script src="/sammy.js"></script>
            <script src="/browser/app.js"></script>
          </head>
          <body>
            <div id="main">
              <a href="/browser/dead">Kill</a>
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

      brains.get "/browser/app.js", (req, res)->
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
        $(function() { Sammy("#main").run("#/"); });
        """
      browser = new Browser
      browser.wants "http://localhost:3003/browser/walking", @callback

    "queryAll":
      topic: (browser)->
        browser.queryAll(".now")
      "should return array of nodes": (nodes)->
        assert.lengthOf nodes, 1

    "query method":
      topic: (browser)->
        browser.query(".now")
      "should return single node": (node)->
        assert.equal node.tagName, "DIV"

    "query text":
      topic: (browser)->
        browser
      "should query from document": (browser)->
        assert.equal browser.text(".now"), "Walking Aimlessly"
      "should query from context (exists)": (browser)->
        assert.equal browser.text(".now"), "Walking Aimlessly"
      "should query from context (unrelated)": (browser)->
        assert.equal browser.text(".now", browser.querySelector("form")), ""
      "should combine multiple elements": (browser)->
        assert.equal browser.text("form label"), "Email Password "

    "query html":
      topic: (browser)->
        browser
      "should query from document": (browser)->
        assert.equal browser.html(".now"), "<div class=\"now\">Walking Aimlessly</div>"
      "should query from context (exists)": (browser)->
        assert.equal browser.html(".now", browser.body), "<div class=\"now\">Walking Aimlessly</div>"
      "should query from context (unrelated)": (browser)->
        assert.equal browser.html(".now", browser.querySelector("form")), ""
      "should combine multiple elements": (browser)->
        assert.equal browser.html("title, #main a"), "<title>The Living</title><a href=\"/browser/dead\">Kill</a>"

    "jQuery":
      topic: (browser)->
        browser.evaluate('window.jQuery')
      "should query by id": ($)->
        assert.equal $('#main').size(), 1
      "should query by element name": ($)->
        assert.equal $('form').attr('action'), '#/dead'
      "should query by element name (multiple)": ($)->
        assert.equal $('label').size(), 2
      "should query with descendant selectors": ($)->
        assert.equal $('body #main a').text(), 'Kill'
      "should query in context": ($)->
        assert.equal $('body').find('#main a', 'body').text(), 'Kill'
      "should query in context": ($)->
        assert.equal $('body').find('#main a', 'body').text(), 'Kill'
      "should query in context with find()": ($)->
        assert.equal $('body').find('#main a').text(), 'Kill'


.export(module)
