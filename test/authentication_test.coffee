{ assert, brains, Browser } = require("./helpers")


describe "Authentication", ->

  describe "basic", ->
    before (done)->
      brains.get "/auth/basic", (req, res) ->
        if auth = req.headers.authorization
          if auth == "Basic dXNlcm5hbWU6cGFzczEyMw=="
            res.send "<html><body>#{req.headers["authorization"]}</body></html>"
          else
            res.send "Invalid credentials", 401
        else
          res.send "Missing credentials", 401
      brains.ready done


    describe "without credentials", ->
      before (done)->
        @browser = new Browser()
        @browser.visit("http://localhost:3003/auth/basic").
          finally(done)

      it "should return status code 401", ->
        assert.equal @browser.statusCode, 401


    describe "with invalid credentials", ->
      before (done)->
        @browser = new Browser()
        @browser.authenticate("localhost:3003").basic("username", "wrong")
        @browser.visit("http://localhost:3003/auth/basic")
          .finally(done)

      it "should return status code 401", ->
        assert.equal @browser.statusCode, 401

    describe "with valid credentials", ->
      before (done)->
        @browser = new Browser()
        @browser.authenticate("localhost:3003").basic("username", "pass123")
        @browser.visit "http://localhost:3003/auth/basic", done

      it "should have the authentication header", ->
        assert.equal @browser.text("body"), "Basic dXNlcm5hbWU6cGFzczEyMw=="

    describe "legacy credentials", ->
      before (done)->
        @browser = new Browser()
        credentials = { scheme: "basic", user: "username", password: "pass123" }
        @browser.visit "http://localhost:3003/auth/basic", credentials: credentials, done

      it "should have the authentication header", ->
        assert.equal @browser.text("body"), "Basic dXNlcm5hbWU6cGFzczEyMw=="


  describe "OAuth bearer", ->
    before (done)->
      brains.get "/auth/oauth2", (req, res) ->
        if auth = req.headers.authorization
          if auth == "Bearer 12345"
            res.send "<html><body>#{req.headers["authorization"]}</body></html>"
          else
            res.send "Invalid token", 401
        else
          res.send "Missing token", 401
      brains.ready done

    describe "without credentials", ->
      before (done)->
        @browser = new Browser()
        @browser.visit("http://localhost:3003/auth/oauth2")
          .finally(done)

      it "should return status code 401", ->
        assert.equal @browser.statusCode, 401

    describe "with invalid credentials", ->
      before (done)->
        @browser = new Browser()
        @browser.authenticate("localhost:3003").bearer("wrong")
        @browser.visit("http://localhost:3003/auth/oauth2")
          .finally(done)

      it "should return status code 401", ->
        assert.equal @browser.statusCode, 401

    describe "with valid credentials", ->
      before (done)->
        @browser = new Browser()
        @browser.authenticate("localhost:3003").bearer("12345")
        @browser.visit "http://localhost:3003/auth/oauth2", done

      it "should have the authentication header", ->
        assert.equal @browser.text("body"), "Bearer 12345"


  describe "Scripts on secure pages", ->
    before (done) ->
      brains.get "/auth/script", (req, res) ->
        if auth = req.headers.authorization
          res.send """
          <html>
            <head>
              <title>Zero</title>
              <script src="/auth/script.js"></script>
            </head>
            <body></body>
          </html>
          """
        else
          res.send "No Credentials on the html page", 401

      brains.get "/auth/script.js", (req, res) ->
        if auth = req.headers.authorization
          res.send "document.title = document.title + 'One'"
        else
          res.send "No Credentials on the javascript", 401

      @browser = new Browser()
      @browser.authenticate("localhost:3003").basic("username", "pass123")
      @browser.visit "http://localhost:3003/auth/script", done

    it "should download the script", ->
      assert.equal @browser.text("title"), "ZeroOne"
