{ Vows, assert, brains, Browser } = require("./helpers")

Vows.describe("Authentication").addBatch

  "basic":
    topic: ->
      brains.get "/auth/basic", (req, res) ->
        if auth = req.headers.authorization
          if auth == "Basic dXNlcm5hbWU6cGFzczEyMw=="
            res.send "<html><body>#{req.headers["authorization"]}</body></html>"
          else
            res.send "Invalid credentials", 401
        else
          res.send "Missing credentials", 401
      brains.ready @callback

    "without credentials":
      topic: ->
        browser = new Browser
        browser.visit "http://localhost:3003/auth/basic", @callback
      "should return status code 401": (browser)->
        assert.equal browser.statusCode, 401

    "with invalid credentials":
      topic: ->
        browser = new Browser
        credentials = { scheme: "basic", user: "username", password: "wrong" }
        browser.visit "http://localhost:3003/auth/basic", credentials: credentials, @callback
      "should return status code 401": (browser)->
        assert.equal browser.statusCode, 401

    "with valid credentials":
      topic: ->
        browser = new Browser
        credentials = { scheme: "basic", user: "username", password: "pass123" }
        browser.visit "http://localhost:3003/auth/basic", credentials: credentials, @callback
      "should have the authentication header": (browser)->
        assert.equal browser.text("body"), "Basic dXNlcm5hbWU6cGFzczEyMw=="


  "OAuth bearer":
    topic: ->
      brains.get "/auth/oauth2", (req, res) ->
        if auth = req.headers.authorization
          if auth == "Bearer 12345"
            res.send "<html><body>#{req.headers["authorization"]}</body></html>"
          else
            res.send "Invalid token", 401
        else
          res.send "Missing token", 401
      brains.ready @callback

    "without credentials":
      topic: ->
        browser = new Browser
        browser.visit "http://localhost:3003/auth/oauth2", @callback
      "should return status code 401": (browser)->
        assert.equal browser.statusCode, 401

    "with invalid credentials":
      topic: ->
        browser = new Browser
        credentials = { scheme: "bearer", token: "wrong" }
        browser.visit "http://localhost:3003/auth/oauth2", credentials: credentials, @callback
      "should return status code 401": (browser)->
        assert.equal browser.statusCode, 401

    "with valid credentials":
      topic: ->
        browser = new Browser
        credentials = { scheme: "bearer", token: "12345" }
        browser.visit "http://localhost:3003/auth/oauth2", credentials: credentials, @callback
      "should have the authentication header": (browser)->
        assert.equal browser.text("body"), "Bearer 12345"


.export(module)
