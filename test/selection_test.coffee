{ assert, brains, Browser } = require("./helpers")


describe "Selection", ->

  before (done)->
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
          <button>Do not press!</button>
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

    brains.ready done

  before (done)->
    @browser = new Browser()
    @browser.visit("http://localhost:3003/browser/walking")
      .then(done, done)


  describe "queryAll", ->
    it "should return array of nodes", ->
      nodes = @browser.queryAll(".now")
      assert.equal nodes.length, 1


  describe "query method", ->
    it "should return single node", ->
      node = @browser.query(".now")
      assert.equal node.tagName, "DIV"


  describe "the tricky ID", ->
    before ->
      @root = @browser.document.getElementById("main")

    it "should find child from id", ->
      nodes = @root.querySelectorAll("#main button")
      assert.equal nodes[0].textContent, "Sign Me Up"

    it "should find child from parent", ->
      nodes = @root.querySelectorAll("button")
      assert.equal nodes[0].textContent, "Sign Me Up"

    it "should not re-find element itself", ->
      nodes = @root.querySelectorAll("#main")
      assert.equal nodes.length, 0

    it "should not find children of siblings", ->
      nodes = @root.querySelectorAll("button")
      assert.equal nodes.length, 1


  describe "query text", ->
    it "should query from document", ->
      assert.equal @browser.text(".now"), "Walking Aimlessly"
    it "should query from context (exists)", ->
      assert.equal @browser.text(".now"), "Walking Aimlessly"
    it "should query from context (unrelated)", ->
      assert.equal @browser.text(".now", @browser.querySelector("form")), ""
    it "should combine multiple elements", ->
      assert.equal @browser.text("form label"), "Email Password"


  describe "query html", ->
    it "should query from document", ->
      assert.equal @browser.html(".now"), "<div class=\"now\">Walking Aimlessly</div>"
    it "should query from context (exists)", ->
      assert.equal @browser.html(".now", @browser.body), "<div class=\"now\">Walking Aimlessly</div>"
    it "should query from context (unrelated)", ->
      assert.equal @browser.html(".now", @browser.querySelector("form")), ""
    it "should combine multiple elements", ->
      assert.equal @browser.html("title, #main a"), "<title>The Living</title><a href=\"/browser/dead\">Kill</a>"

  describe "button", ->
    describe "when passed a valid HTML element", ->
      it "should return the already queried element", ->
        elem = @browser.querySelector "button:first"
        assert.equal @browser.button(elem), elem

  describe "link", ->
    describe "when passed a valid HTML element", ->
      it "should return the already queried element", ->
        elem = @browser.querySelector "a:first"
        assert.equal @browser.link(elem), elem

  describe "field", ->
    describe "when passed a valid HTML element", ->
      it "should return the already queried element", ->
        elem = @browser.querySelector "input[name='email']"
        assert.equal @browser.field(elem), elem

  describe "jQuery", ->
    before ->
      @$ = @browser.evaluate('window.jQuery')

    it "should query by id", ->
      assert.equal @$('#main').size(), 1
    it "should query by element name", ->
      assert.equal @$('form').attr('action'), '#/dead'
    it "should query by element name (multiple)", ->
      assert.equal @$('label').size(), 2
    it "should query with descendant selectors", ->
      assert.equal @$('body #main a').text(), 'Kill'
    it "should query in context", ->
      assert.equal @$('body').find('#main a', 'body').text(), 'Kill'
    it "should query in context with find()", ->
      assert.equal @$('body').find('#main a').text(), 'Kill'

