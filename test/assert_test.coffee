{ assert, brains, Browser } = require("./helpers")


describe "browser.assert", ->
 
  browser = null
  before (done) ->
    browser = Browser.create()
    brains.ready(done)

  describe.only ".link", ->
    before ->
      brains.get "/assert/link", (req, res) ->
        res.send """
        <!DOCTYPE html>
        <html lang=en>
          <head><title>test</title></head>
          <body>
            <div>
              <p id="p-id">
                <a href="/assert/link/link-to-some-id-12345" id="link-id">Link Text</a>
              </p>
            </div>
          </body>
        </html>
        """
      brains.get "/assert/link/link-to-some-id-12345", (req, res) ->
        res.send """
          <html>
            <body>
            </body>
          </html>
        """


    before (done) ->
      browser.visit("/assert/link", done)

    it "should find the link using a wide selector", ->
      browser.assert.link("a", 'Link Text', '/assert/link/link-to-some-id-12345')

    it "should find the link using a specific selector", ->
      browser.assert.link("div p a", "Link Text", "/assert/link/link-to-some-id-12345")

    it "should find the link using an id selector", ->
      browser.assert.link("#link-id", "Link Text", "/assert/link/link-to-some-id-12345")

    it "should find the link when given a RegExp for the url"
