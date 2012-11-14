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


  describe "as array", ->
    before (done)->
      @browser = new Browser()
      @browser.visit "http://localhost:3003/browser/resource", done

    it "should have a length", ->
      assert.equal @browser.resources.length, 2
    it "should include loaded page", ->
      assert.equal @browser.resources[0].response.url, "http://localhost:3003/browser/resource"
    it "should include loaded JavaScript", ->
      assert.equal @browser.resources[1].response.url, "http://localhost:3003/jquery-1.7.1.js"

    after ->
      @browser.destroy()


  describe "fail URL", ->
    before (done)->
      @browser = new Browser()
      @browser.resources.fail("http://localhost:3003/browser/resource", "Fail!")
      @browser.visit "http://localhost:3003/browser/resource", (@error)=>
        done()

    it "should fail the request", ->
      assert.equal @error.message, "Fail!"

    after ->
      @browser.destroy()


  describe "delay URL with timeout", ->
    before (done)->
      @browser = new Browser()
      @browser.resources.delay("http://localhost:3003/browser/resource", 100)
      @browser.visit "http://localhost:3003/browser/resource"
      @browser.wait duration: 90, done

    it "should not load page", ->
      @browser.assert.text "title", ""

    describe "after delay", ->
      before (done)->
        @browser.wait duration: 90, done

      it "should successfully load page", ->
        @browser.assert.text "title", "Awesome"

    after ->
      @browser.destroy()


  describe "mock URL", ->
    before (done)->
      @browser = new Browser()
      @browser.resources.mock("http://localhost:3003/browser/resource", statusCode: 204, body: "empty")
      @browser.visit "http://localhost:3003/browser/resource", done

    it "should return mock result", ->
      @browser.assert.status 204
      @browser.assert.text "body", "empty"

    describe "restore", ->
      before (done)->
        @browser.resources.restore("http://localhost:3003/browser/resource")
        @browser.visit "http://localhost:3003/browser/resource", done

      it "should return actual page", ->
        @browser.assert.text "title", "Awesome"

    after ->
      @browser.destroy()


