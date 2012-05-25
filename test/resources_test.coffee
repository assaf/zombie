{ assert, brains, Browser } = require("./helpers")


describe "Resources", ->

  before (done)->
    brains.get "/browser/resource", (req, res)->
      res.send """
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
        <script type="text/x-do-not-parse">
          <p>this is not valid JavaScript</p>
        </script>
      </html>
      """
    brains.ready done


  before (done)->
    @browser = new Browser()
    @browser.visit "http://localhost:3003/browser/resource", done

  it "should exist on the browser", ->
    assert @browser.resources
  it "should have a length", ->
    assert.equal @browser.resources.length, 2
  it "should include jquery", ->
    assert.equal @browser.resources[1].url, "http://localhost:3003/jquery-1.7.1.js"
  it "should include the 'self' url", ->
    assert.equal @browser.resources[0].url, "http://localhost:3003/browser/resource"
  it "should have a 'dump' method", ->
    try
      @browser.resources.toString()
    catch e
      assert false, "calling dump method throws an error [" + e + "]"

