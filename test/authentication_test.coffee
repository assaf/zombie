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
      browser = new Browser()
      before (done)->
        browser.visit "http://localhost:3003/auth/basic", ->
          done()

      it "should return status code 401", ->
        assert.equal browser.statusCode, 401

    describe "with invalid credentials", ->
      browser = new Browser()
      before (done)->
        credentials = { scheme: "basic", user: "username", password: "wrong" }
        browser.visit "http://localhost:3003/auth/basic", credentials: credentials, ->
          done()

      it "should return status code 401", ->
        assert.equal browser.statusCode, 401

    describe "with valid credentials", ->
      browser = new Browser()
      before (done)->
        credentials = { scheme: "basic", user: "username", password: "pass123" }
        browser.visit "http://localhost:3003/auth/basic", credentials: credentials, done

      it "should have the authentication header", ->
        assert.equal browser.text("body"), "Basic dXNlcm5hbWU6cGFzczEyMw=="


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
      browser = new Browser()
      before (done)->
        browser.visit "http://localhost:3003/auth/oauth2", ->
          done()

      it "should return status code 401", ->
        assert.equal browser.statusCode, 401

    describe "with invalid credentials", ->
      browser = new Browser()
      before (done)->
        credentials = { scheme: "bearer", token: "wrong" }
        browser.visit "http://localhost:3003/auth/oauth2", credentials: credentials, ->
          done()

      it "should return status code 401", ->
        assert.equal browser.statusCode, 401

    describe "with valid credentials", ->
      browser = new Browser()
      before (done)->
        credentials = { scheme: "bearer", token: "12345" }
        browser.visit "http://localhost:3003/auth/oauth2", credentials: credentials, done

      it "should have the authentication header", ->
        assert.equal browser.text("body"), "Bearer 12345"

  describe 'Scripts on secure pages', ->
    browser = new Browser({debug: true, runScripts: true})
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
          res.send "No Credentials", 401

      brains.get "auth/script.js", (req, res) ->
        if auth = req.headers.authorization
          res.send "document.title = document.title + 'One'"
        else
          res.send "No Credentials", 401

      credentials = { scheme: "basic", user: "username", password: "pass123" }
      browser.visit "http://localhost:3003/auth/script", credentials: credentials, done

    it "should download the script", ->
      assert.equal browser.text("title"), "ZeroOne"
