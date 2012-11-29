{ assert, brains, Browser } = require("./helpers")


test = (scope)->
  describe "initial", ->
    before (done)->
      Browser.visit "/storage", (error, browser)=>
        @storage = scope(browser.window)
        done(error)

    it "should start with no keys", ->
      assert.equal @storage.length, 0
    it "should handle key() with no key", ->
      assert !@storage.key(1)
    it "should handle getItem() with no item", ->
      assert.equal @storage.getItem("nosuch"), null
    it "should handle removeItem() with no item", ->
      assert.doesNotThrow =>
        @storage.removeItem("nosuch")
    it "should handle clear() with no items", ->
      assert.doesNotThrow =>
        @storage.clear()


  describe "add some items", ->
    before (done)->
      Browser.visit "/storage", (error, browser)=>
        @storage = scope(browser.window)
        @storage.setItem "is", "hungry"
        @storage.setItem "wants", "brains"
        done(error)

    it "should count all items in length", ->
      assert.equal @storage.length, 2
    it "should make key available", ->
      keys = [@storage.key(0), @storage.key(1)].sort()
      assert.deepEqual keys, ["is", "wants"]
    it "should make value available", ->
      assert.equal @storage.getItem("is"), "hungry"
      assert.equal @storage.getItem("wants"), "brains"


  describe "change an item", ->
    before (done)->
      Browser.visit "/storage", (error, browser)=>
        @storage = scope(browser.window)
        @storage.setItem "is", "hungry"
        @storage.setItem "wants", "brains"
        @storage.setItem "is", "dead"
        @keys = [@storage.key(0), @storage.key(1)].sort()
        done(error)

    it "should leave length intact", ->
      assert.equal @storage.length, 2
    it "should keep key position", ->
      assert.deepEqual [@storage.key(0), @storage.key(1)].sort(), @keys
    it "should change value", ->
      assert.equal @storage.getItem("is"), "dead"
    it "should not change other values", ->
      assert.equal @storage.getItem("wants"), "brains"


  describe "remove an item", ->
    before (done)->
      Browser.visit "/storage", (error, browser)=>
        @storage = scope(browser.window)
        @storage.setItem "is", "hungry"
        @storage.setItem "wants", "brains"
        @storage.removeItem "is"
        done(error)

    it "should drop item from length", ->
      assert.equal @storage.length, 1
    it "should forget key", ->
      assert.equal @storage.key(0), "wants"
      assert !@storage.key(1)
    it "should forget value", ->
      assert.equal @storage.getItem("is"), null
      assert.equal @storage.getItem("wants"), "brains"


  describe "clean all items", ->
    before (done)->
      Browser.visit "/storage", (error, browser)=>
        @storage = scope(browser.window)
        @storage.setItem "is", "hungry"
        @storage.setItem "wants", "brains"
        @storage.clear()
        done(error)

    it "should reset length to zero", ->
      assert.equal @storage.length, 0
    it "should forget all keys", ->
      assert !@storage.key(0)
    it "should forget all values", ->
      assert.equal @storage.getItem("is"), null
      assert.equal @storage.getItem("wants"), null


  describe "store null", ->
    before (done)->
      Browser.visit "/storage", (error, browser)=>
        @storage = scope(browser.window)
        @storage.setItem "null", null
        done(error)

    it "should store that item", ->
      assert.equal @storage.length, 1
    it "should return null for key", ->
      assert.equal @storage.getItem("null"), null


describe "Storage", ->
  before (done)->
    brains.get "/storage", (req, res)->
      res.send ""
    brains.ready done

  describe "local storage", ->
    test.call this, (window)->
      window.localStorage

  describe "session storage", ->
    test.call this, (window)->
      window.sessionStorage

