{ assert, brains, Browser } = require("./helpers")
File = require("fs")
Zlib = require("zlib")


describe "Resources", ->

  before (done)->
    brains.get "/resources/resource", (req, res)->
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
      @browser.visit "/resources/resource", done

    it "should have a length", ->
      assert.equal @browser.resources.length, 2
    it "should include loaded page", ->
      assert.equal @browser.resources[0].response.url, "http://localhost:3003/resources/resource"
    it "should include loaded JavaScript", ->
      assert.equal @browser.resources[1].response.url, "http://localhost:3003/jquery-1.7.1.js"

    after ->
      @browser.destroy()


  describe "fail URL", ->
    before (done)->
      @browser = new Browser()
      @browser.resources.fail("http://localhost:3003/resource/resource", "Fail!")
      @browser.visit "/resource/resource", (@error)=>
        done()

    it "should fail the request", ->
      assert.equal @error.message, "Fail!"

    after ->
      @browser.destroy()


  describe "delay URL with timeout", ->
    before (done)->
      @browser = new Browser()
      @browser.resources.delay("http://localhost:3003/resources/resource", 100)
      @browser.visit "/resources/resource"
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
      @browser.resources.mock("http://localhost:3003/resources/resource", statusCode: 204, body: "empty")
      @browser.visit "/resources/resource", done

    it "should return mock result", ->
      @browser.assert.status 204
      @browser.assert.text "body", "empty"

    describe "restore", ->
      before (done)->
        @browser.resources.restore("http://localhost:3003/resources/resource")
        @browser.visit "/resources/resource", done

      it "should return actual page", ->
        @browser.assert.text "title", "Awesome"

    after ->
      @browser.destroy()


  describe "deflate", ->
    before ->
      brains.get "/resources/deflate", (req, res)->
        res.setHeader "Transfer-Encoding", "deflate"
        image = File.readFileSync("#{__dirname}/data/zombie.jpg")
        Zlib.deflate image, (error, buffer)->
          res.send(buffer)

    before (done)->
      @browser = new Browser()
      @browser.resources.get "http://localhost:3003/resources/deflate", (error, @response)=>
        done()

    it "should uncompress deflated response", ->
      image = File.readFileSync("#{__dirname}/data/zombie.jpg")
      assert.deepEqual image, @response.body

    after ->
      @browser.destroy()


  describe "gzip", ->
    before ->
      brains.get "/resources/gzip", (req, res)->
        res.setHeader "Transfer-Encoding", "gzip"
        image = File.readFileSync("#{__dirname}/data/zombie.jpg")
        Zlib.gzip image, (error, buffer)->
          res.send(buffer)

    before (done)->
      @browser = new Browser()
      @browser.resources.get "http://localhost:3003/resources/gzip", (error, @response)=>
        done()

    it "should uncompress gzipped response", ->
      image = File.readFileSync("#{__dirname}/data/zombie.jpg")
      assert.deepEqual image, @response.body

    after ->
      @browser.destroy()


  describe "301 redirect URL", ->
    before ->
      brains.get "/resources/three-oh-one", (req, res)->
        res.redirect("/resources/resource", 301)

    before (done)->
      @browser = new Browser()
      @browser.visit "/resources/three-oh-one", done

    it "should have a length", ->
      assert.equal @browser.resources.length, 2
    it "should include loaded page", ->
      assert.equal @browser.resources[0].response.url, "http://localhost:3003/resources/resource"
    it "should include loaded JavaScript", ->
      assert.equal @browser.resources[1].response.url, "http://localhost:3003/jquery-1.7.1.js"

    after ->
      @browser.destroy()
