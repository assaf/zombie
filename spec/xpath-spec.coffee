require "./helpers"
{ vows: vows, assert: assert, zombie: zombie, brains: brains } = require("vows")

brains.get "/xpath", (req, res)-> res.send """
  <div>
    <p id='first'>First paragraph</p>
    <p>Second paragraph</p>
  </div>
  """

vows.describe("XPath").addBatch(
  "evaluate nodes":
    zombie.wants "http://localhost:3003/xpath"
      topic: (browser)->
        browser.xpath("//p")
      "should return result type node-set": (result)-> assert.equal result.type, "node-set"
      "should return two nodes": (result)-> assert.length result.value, 2
      "should return first paragraph": (result)-> assert.equal result.value[0].textContent, "First paragraph"
      "should return second paragraph": (result)-> assert.equal result.value[1].textContent, "Second paragraph"
  "evaluate number":
    zombie.wants "http://localhost:3003/xpath"
      topic: (browser)->
        browser.xpath("count(//p)")
      "should return result type number": (result)-> assert.equal result.type, "number"
      "should return number of nodes": (result)-> assert.equal result.value, 2
  "evaluate string":
    zombie.wants "http://localhost:3003/xpath"
      topic: (browser)->
        browser.xpath("'foobar'")
      "should return result type number": (result)-> assert.equal result.type, "string"
      "should return number of nodes": (result)-> assert.equal result.value, "foobar"
  "evaluate boolean":
    zombie.wants "http://localhost:3003/xpath"
      topic: (browser)->
        browser.xpath("2 + 2 = 4")
      "should return result type number": (result)-> assert.equal result.type, "boolean"
      "should return number of nodes": (result)-> assert.equal result.value, true
).export(module)
