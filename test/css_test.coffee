{ brains, Browser } = require("./helpers")


describe "CSS", ->

  browser = null
  before (done)->
    browser = Browser.create()
    brains.ready(done)

  describe "style", ->

    before ->
      brains.get "/styled", (req, res)-> res.send """
        <html>
          <body>
            <div id="styled"></div>
          </body>
        </html>
      """

    before (done)->
      browser.visit("http://localhost:3003/styled", done)

    it "should be formatted string", ->
      browser.query("#styled").style.opacity = .55
      browser.assert.style "#styled", "opacity", "0.55"

    it "should not accept non-numbers", ->
      browser.query("#styled").style.opacity = ".46"
      browser.query("#styled").style.opacity = "four-six"
      browser.assert.style "#styled", "opacity", "0.46"

    it "should default to empty string", ->
      style = browser.query("#styled").style
      style.opacity = 1.0
      style.opacity = undefined
      browser.assert.style "#styled", "opacity", ""
      style.opacity = 1.0
      style.opacity = null
      browser.assert.style "#styled", "opacity", ""


  after ->
    browser.destroy()
