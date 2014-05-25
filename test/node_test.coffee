{ assert, brains, Browser } = require("./helpers")
File = require("fs")

describe "Node", ->

  browser = null
  before (done)->
    browser = Browser.create()
    brains.ready(done)

  describe ".contains", ->

    before ->
      brains.get "/node/contains.html", (req, res)-> res.send """
        <html>
          <body>
            <div class="body-child"></div>
            <div class="parent">
              <div class="child"></div>
            </div>
          </body>
        </html>
      """

    before (done)->
      browser.visit("/node/contains.html", done)

      
    it "should be true for direct children", ->
      bodyChild = browser.query '.body-child'
      assert.strictEqual browser.document.body.contains(bodyChild), true
  
    it "should be true for grandchild children", ->
      child = browser.query '.child'
      assert.strictEqual browser.document.body.contains(child), true

    it "should be false for siblings", ->
      bodyChild = browser.query '.body-child'
      parent = browser.query '.parent'
      assert.strictEqual parent.contains(bodyChild), false

    it "should be false for parent", ->
      child = browser.query '.child'
      parent = browser.query '.parent'
      assert.strictEqual child.contains(parent), false

    it "should be false for self", ->
      child = browser.query '.child'
      assert.strictEqual child.contains(child), false
