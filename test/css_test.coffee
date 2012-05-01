{ assert, brains, Browser } = require("./helpers")


describe "CSS", ->

  describe "style", ->

    style = null

    before (done)->
      brains.get "/styled", (req, res)-> res.send """
        <html>
          <body>
            <div id="styled"></div>
          </body>
        </html>
      """
      brains.ready done

    before (done)->
      browser = new Browser()
      browser.visit "http://localhost:3003/styled", ->
        style = browser.query("#styled").style
        done()

    it "should be formatted string", ->
      style.opacity = .55
      assert.equal typeof style.opacity, "string"
      assert.equal style.opacity, "0.55"
    it "should not accept non-numbers", ->
      style.opacity = ".46"
      style.opacity = "four-six"
      assert.equal style.opacity, "0.46"
    it "should default to empty string", ->
      style.opacity = 1.0
      style.opacity = undefined
      assert.equal style.opacity, ""
      style.opacity = null
      assert.equal style.opacity, ""

