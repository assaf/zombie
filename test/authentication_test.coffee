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

  describe 'Fetching scripts on secure pages', ->
    describe 'from the same domain', ->
      browser = new Browser()
      before (done) ->
        brains.get "/auth/sameDomain", (req, res) ->
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
            res.send "document.title = 'Authed'"
          else
            res.send "No Credentials on the javascript", 401

        credentials = { scheme: "basic", user: "username", password: "pass123"}
        browser.visit "http://localhost:3003/auth/sameDomain", credentials: credentials, done

      it "should send credentials", ->
        assert.equal browser.text("title"), "Authed"

    describe 'from a different domain', ->
      browser = new Browser()
      before (done) ->
        brains.get "/auth/differentDomain", (req, res) ->
          if auth = req.headers.authorization
            res.send """
            <html>
              <head>
                <title>Zero</title>
                <script src="/noauth/script.js"></script>
              </head>
              <body></body>
            </html>
            """
          else
            res.send "No Credentials on the html page", 401

        brains.get "/noauth/script.js", (req, res) ->
          if req.headers.authorization
            res.send "Unsupported Authorization", 400
          else
            res.send "document.title = 'Worked'"

        credentials = { scheme: "basic", user: "username", password: "pass123", site: "http://localhost:3003/auth"}
        browser.visit "http://localhost:3003/auth/differentDomain", credentials: credentials, done

      it 'should not send credentials', ->
        assert.equal browser.text("title"), "Worked"
