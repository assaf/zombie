{ brains, Browser } = require("./helpers")


describe "Authentication", ->
  browser = null
  before (done)->
    browser = Browser.create()
    brains.ready(done)

  describe "basic", ->
    before ->
      brains.get "/auth/basic", (req, res) ->
        if auth = req.headers.authorization
          if auth == "Basic dXNlcm5hbWU6cGFzczEyMw=="
            res.send "<html><body>#{req.headers["authorization"]}</body></html>"
          else
            res.send "Invalid credentials", 401
        else
          res.send "Missing credentials", 401


    describe "without credentials", ->
      before (done)->
        browser.visit("/auth/basic")
          .fail ->
            done()

      it "should return status code 401", ->
        browser.assert.status 401


    describe "with invalid credentials", ->
      before (done)->
        browser.authenticate("localhost:3003").basic("username", "wrong")
        browser.visit("/auth/basic")
          .fail ->
            done()

      it "should return status code 401", ->
        browser.assert.status 401

    describe "with valid credentials", ->
      before (done)->
        browser.authenticate("localhost:3003").basic("username", "pass123")
        browser.visit("/auth/basic", done)

      it "should have the authentication header", ->
        browser.assert.text "body", "Basic dXNlcm5hbWU6cGFzczEyMw=="


  describe "OAuth bearer", ->
    before ->
      brains.get "/auth/oauth2", (req, res) ->
        if auth = req.headers.authorization
          if auth == "Bearer 12345"
            res.send("<html><body>#{req.headers["authorization"]}</body></html>")
          else
            res.send("Invalid token", 401)
        else
          res.send("Missing token", 401)

    describe "without credentials", ->
      before (done)->
        browser.visit("/auth/oauth2")
          .fail ->
            done()

      it "should return status code 401", ->
        browser.assert.status 401

    describe "with invalid credentials", ->
      before (done)->
        browser.authenticate("localhost:3003").bearer("wrong")
        browser.visit("/auth/oauth2")
          .fail ->
            done()

      it "should return status code 401", ->
        browser.assert.status 401

    describe "with valid credentials", ->
      before (done)->
        browser.authenticate("localhost:3003").bearer("12345")
        browser.visit("/auth/oauth2", done)

      it "should have the authentication header", ->
        browser.assert.text "body", "Bearer 12345"


  describe "Scripts on secure pages", ->
    before ->
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
          res.send("No Credentials on the html page", 401)

      brains.get "/auth/script.js", (req, res) ->
        if auth = req.headers.authorization
          res.send("document.title = document.title + 'One'")
        else
          res.send("No Credentials on the javascript", 401)

    before (done)->
      browser.authenticate("localhost:3003").basic("username", "pass123")
      browser.visit("/auth/script", done)

    it "should download the script", ->
      browser.assert.text "title", "ZeroOne"


  after ->
    browser.destroy()
