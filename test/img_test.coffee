{ assert, brains, Browser } = require("./helpers")
File = require("fs")

describe "IMG", ->

  browser = null
  before (done)->
    browser = Browser.create()
    browser.features = "img"
    brains.ready(done)

  describe "style", ->

    before ->
      brains.get "/image/index.html", (req, res)-> res.send """
        <html>
          <body>
            <img src="/image/zombie.jpg" />
          </body>
        </html>
      """
      brains.get "/image/zombie.jpg", (req, res) ->
        res.setHeader("Content-Type","image/jpeg");
        res.send File.readFileSync("#{__dirname}/data/zombie.jpg")

    before (done)->
      browser.visit("http://localhost:3003/image/index.html", done)

    it "should have 2 resources", ->
      assert.equal browser.resources.length, 2

    it "should be in resources", ->
      assert.equal browser.resources[1].response.url, "http://localhost:3003/image/zombie.jpg"

    it "should be the same as original file", ->
      assert.deepEqual browser.resources[1].response.body, File.readFileSync("#{__dirname}/data/zombie.jpg")

  after ->
    browser.destroy()
