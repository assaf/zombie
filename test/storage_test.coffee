{ Vows, assert, Browser } = require("./helpers")


test = (scope)->
  describe "initial", ->
    storage = null

    before (done)->
      Browser.visit "http://localhost:3003/storage", (_, browser)->
        storage = scope(browser.window)
        done()

    it "should start with no keys", ->
      assert.equal storage.length, 0
    it "should handle key() with no key", ->
      assert !storage.key(1)
    it "should handle getItem() with no item", ->
      it assert !storage.getItem("nosuch")
    it "should handle removeItem() with no item", ->
      assert.doesNotThrow ->
        storage.removeItem("nosuch")
    it "should handle clear() with no items", ->
      assert.doesNotThrow ->
        storage.clear()


  describe "add some items", ->
    storage = null

    before (done)->
      Browser.visit "http://localhost:3003/storage", (_, browser)->
        storage = scope(browser.window)
        storage.setItem "is", "hungry"
        storage.setItem "wants", "brains"
        done()

    it "should count all items in length", ->
      assert.equal storage.length, 2
    it "should make key available", ->
      keys = [storage.key(0), storage.key(1)].sort()
      assert.deepEqual keys, ["is", "wants"]
    it "should make value available", ->
      assert.equal storage.getItem("is"), "hungry"
      assert.equal storage.getItem("wants"), "brains"


  describe "change an item", ->
    storage = keys = null

    before (done)->
      Browser.visit "http://localhost:3003/storage", (_, browser)->
        storage = scope(browser.window)
        storage.setItem "is", "hungry"
        storage.setItem "wants", "brains"
        storage.setItem "is", "dead"
        keys = [storage.key(0), storage.key(1)].sort()
        done()

    it "should leave length intact", ->
      assert.equal storage.length, 2
    it "should keep key position", ->
      assert.deepEqual [storage.key(0), storage.key(1)].sort(), keys
    it "should change value", ->
      assert.equal storage.getItem("is"), "dead"
    it "should not change other values", ->
      assert.equal storage.getItem("wants"), "brains"


  describe "remove an item", ->
    storage = null

    before (done)->
      Browser.visit "http://localhost:3003/storage", (_, browser)->
        storage = scope(browser.window)
        storage.setItem "is", "hungry"
        storage.setItem "wants", "brains"
        storage.removeItem "is"
        done()

    it "should drop item from length", ->
      assert.equal storage.length, 1
    it "should forget key": (storage)->
      assert.equal storage.key(0), "wants"
      assert !storage.key(1)
    it "should forget value", ->
      assert !storage.getItem("is")
      assert.equal storage.getItem("wants"), "brains"


  describe "clean all items", ->
    storage = null

    before (done)->
      Browser.visit "http://localhost:3003/storage", (_, browser)->
        storage = scope(browser.window)
        storage.setItem "is", "hungry"
        storage.setItem "wants", "brains"
        storage.clear()
        done()

    it "should reset length to zero", ->
      assert.equal storage.length, 0
    it "should forget all keys", ->
      assert !storage.key(0)
    it "should forget all values", ->
      assert !storage.getItem("is")
      assert !storage.getItem("wants")


  describe "store null", ->
    storage = null

    before (done)->
      Browser.visit "http://localhost:3003/storage", (_, browser)->
        storage = scope(browser.window)
        storage.setItem "null", null
        done()

    it "should store that item", ->
      assert.equal storage.length, 1
    it "should return null for key", ->
      assert.equal storage.getItem("null"), null


describe "Storage", ->

  describe "local storage", ->
    test.call this, (window)->
      window.localStorage

  describe "session storage", ->
    test.call this, (window)->
      window.sessionStorage

