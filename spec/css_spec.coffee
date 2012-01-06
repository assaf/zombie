{ Vows, assert, brains, Browser } = require("./helpers")


Vows.describe("CSS").addBatch(
  "opacity":
    topic: ->
      brains.get "/styled", (req, res)-> res.send """
        <body><div id="styled"></div></body>
      """
      browser = new Browser
      browser.wants "http://localhost:3003/styled", =>
        @callback null, browser.query("#styled").style

    "should be formatted string": (style)->
      style.opacity = .55
      assert.typeOf style.opacity, "string"
      assert.equal style.opacity, "0.55"
    "should not accept non-numbers": (style)->
      style.opacity = ".46"
      style.opacity = "four-six"
      assert.equal style.opacity, "0.46"
    "should default to empty string": (style)->
      style.opacity = 1.0
      style.opacity = undefined
      assert.equal style.opacity, ""
      style.opacity = null
      assert.equal style.opacity, ""


).export(module)
