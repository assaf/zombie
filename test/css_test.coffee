{ brains, Browser } = require("./helpers")


describe "CSS", ->

  describe "style", ->

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
      @browser = new Browser()
      @browser.visit("http://localhost:3003/styled", done)

    it "should be formatted string", ->
      @browser.query("#styled").style.opacity = .55
      @browser.assert.css "#styled", "opacity", "0.55"
    it "should not accept non-numbers", ->
      @browser.query("#styled").style.opacity = ".46"
      @browser.query("#styled").style.opacity = "four-six"
      @browser.assert.css "#styled", "opacity", "0.46"
    it "should default to empty string", ->
      style = @browser.query("#styled").style
      style.opacity = 1.0
      style.opacity = undefined
      @browser.assert.css "#styled", "opacity", ""
      style.opacity = null
      @browser.assert.css "#styled", "opacity", ""

