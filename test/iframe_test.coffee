{ assert, brains, Browser } = require("./helpers")


describe "IFrame", ->

  before (done)->
    brains.get "/iframe", (req, res)->
      res.send """
      <html>
        <head>
          <script src="/jquery.js"></script>
        </head>
        <body>
          <iframe src="/static" />
        </body>
      </html>
      """
    brains.get "/static", (req, res)->
      res.send """
      <html>
        <head>
          <title>Whatever</title>
        </head>
        <body>Hello World</body>
      </html>
      """
    brains.ready done

  browser = new Browser()
  iframe = null

  before (done)->
    browser.visit "http://localhost:3003/iframe", ->
      iframe = browser.querySelector("iframe").window
      done()

  it "should load iframe document", ->
    assert.equal "Whatever", iframe.document.title
    assert /Hello World/.test(iframe.document.querySelector("body").innerHTML)
    assert.equal iframe.location, "http://localhost:3003/static"
  it "should reference parent window from iframe", ->
    assert.equal iframe.parent, browser.window.top
  it "should not alter the parent", ->
    assert.equal "http://localhost:3003/iframe", browser.window.location

