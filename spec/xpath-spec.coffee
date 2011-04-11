require "./helpers"
{ vows: vows, assert: assert, zombie: zombie, brains: brains } = require("vows")

brains.get "/xpath", (req, res)-> res.send """
  <h1 id="title">My Blog</h2>

  <ul class="navigation">
    <li><a href="#">First anchor</a></li>
    <li><a href="#">Second anchor</a></li>
    <li><a href="#">Third anchor</a></li>
    <li><a href="#">Fourth anchor</a></li>
    <li><a href="#">Fifth anchor</a></li>
  </ul>

  <div id="posts">
    <div class="post" id="post-1">
      <h2>First post</h2>

      <div class="meta">
        <a href="#">First permalink</a>
        <a href="#">First author</a>
        <a href="#">First comments</a>
      </div>

      <div class="content">
        <p>First paragraph</p>
        <p>Second paragraph</p>
        <p>Third paragraph</p>
      </div>
    </div>

    <div class="post" id="post-2">
      <h2>Second post</h2>

      <div class="meta">
        <a href="#">Second permalink</a>
        <a href="#">Second author</a>
        <a href="#">Second comments</a>
      </div>

      <div class="content">
        <p>Fourth paragraph</p>
        <p>Fifth paragraph</p>
        <p>Sixth paragraph</p>
      </div>
    </div>
  </div>
  """

vows.describe("XPath").addBatch(
  "evaluate nodes":
    zombie.wants "http://localhost:3003/xpath"
      topic: (browser)->
        browser.xpath("//a")
      "should return result type node-set": (result)-> assert.equal result.type, "node-set"
      "should return eleven nodes": (result)-> assert.equal result.value.length, 11
      "should return first anchor": (result)-> assert.equal result.value[0].textContent, "First anchor"
      "should return third anchor": (result)-> assert.equal result.value[2].textContent, "Third anchor"
  "evaluate with id":
    zombie.wants "http://localhost:3003/xpath"
      topic: (browser)->
        browser.xpath('//*[@id="post-2"]/h2')
      "should return one node": (result)-> assert.length result.value, 1
      "should return second post title": (result)-> assert.equal result.value[0].textContent, "Second post"
  "evaluate number":
    zombie.wants "http://localhost:3003/xpath"
      topic: (browser)->
        browser.xpath("count(//a)")
      "should return result type number": (result)-> assert.equal result.type, "number"
      "should return number of nodes": (result)-> assert.equal result.value, 11
  "evaluate string":
    zombie.wants "http://localhost:3003/xpath"
      topic: (browser)->
        browser.xpath("'foobar'")
      "should return result type string": (result)-> assert.equal result.type, "string"
      "should return number of nodes": (result)-> assert.equal result.value, "foobar"
  "evaluate boolean":
    zombie.wants "http://localhost:3003/xpath"
      topic: (browser)->
        browser.xpath("2 + 2 = 4")
      "should return result type boolean": (result)-> assert.equal result.type, "boolean"
      "should return number of nodes": (result)-> assert.equal result.value, true
).export(module)
