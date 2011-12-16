{ Vows, assert, Browser } = require("./helpers")


withStorage = (scope, context)->
  topic = context.topic
  context.topic = ->
    new Browser().wants "http://localhost:3003/", (err, browser)=>
      storage = scope(browser.window)
      topic.call this, storage if topic
      @callback null, storage
  return context

accessTests = (scope)->
  "initial":
    withStorage scope,
      "should start with no keys": (storage)->
        assert.lengthOf storage, 0
      "should handle key() with no key": (storage)->
        assert.isUndefined storage.key(1)
      "should handle getItem() with no item": (storage)->
        assert.isUndefined storage.getItem("nosuch")
      "should handle removeItem() with no item": (storage)->
        assert.doesNotThrow ->
          storage.removeItem("nosuch")
      "should handle clear() with no items": (storage)->
        assert.doesNotThrow ->
          storage.clear()

  "add some items":
    withStorage scope,
      topic: (storage)->
        storage.setItem "is", "hungry"
        storage.setItem "wants", "brains"
      "should count all items in length": (storage)->
        assert.lengthOf storage, 2
      "should make key available": (storage)->
        keys = [storage.key(0), storage.key(1)].sort()
        assert.deepEqual keys, ["is", "wants"]
      "should make value available": (storage)->
        assert.equal storage.getItem("is"), "hungry"
        assert.equal storage.getItem("wants"), "brains"

  "change an item":
    withStorage scope,
      topic: (storage)->
        storage.setItem "is", "hungry"
        storage.setItem "wants", "brains"
        storage.setItem "is", "dead"
        @keys = [storage.key(0), storage.key(1)].sort()
      "should leave length intact": (storage)->
        assert.lengthOf storage, 2
      "should keep key position": (storage)->
        assert.deepEqual [storage.key(0), storage.key(1)].sort(), @keys
      "should change value": (storage)->
        assert.equal storage.getItem("is"), "dead"
      "should not change other values": (storage)->
        assert.equal storage.getItem("wants"), "brains"

  "remove an item":
    withStorage scope,
      topic: (storage)->
        storage.setItem "is", "hungry"
        storage.setItem "wants", "brains"
        storage.removeItem "is"
      "should drop item from length": (storage)->
        assert.lengthOf storage, 1
      "should forget key": (storage)->
        assert.equal storage.key(0), "wants"
        assert.isUndefined storage.key(1)
      "should forget value": (storage)->
        assert.isUndefined storage.getItem("is")
        assert.equal storage.getItem("wants"), "brains"

  "clean all items":
    withStorage scope,
      topic: (storage)->
        storage.setItem "is", "hungry"
        storage.setItem "wants", "brains"
        storage.clear()
      "should reset length to zero": (storage)->
        assert.lengthOf storage, 0
      "should forget all keys": (storage)->
        assert.isUndefined storage.key(0)
      "should forget all values": (storage)->
        assert.isUndefined storage.getItem("is")
        assert.isUndefined storage.getItem("wants")

  "store null":
    withStorage scope,
      topic: (storage)->
        storage.setItem "null", null
      "should store that item": (storage)->
        assert.lengthOf storage, 1
      "should return null for key": (storage)->
        assert.isNull storage.getItem("null")


Vows.describe("Storage").addBatch(

  "local storage":
    accessTests (window)->
      window.localStorage

  "session storage":
    accessTests (window)->
      window.sessionStorage

).export(module)
