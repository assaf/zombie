{ assert, brains, Browser } = require("./helpers")


describe "XPath", ->

  browser = null
  before ->
    browser = Browser.create()

  before (done)->
    brains.get "/xpath", (req, res)-> res.send """
    <html>
      <body>
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
      </body>
    </html>
    """
    brains.ready done

  before (done)->
    browser.visit("http://localhost:3003/xpath", done)


  describe "evaluate nodes", ->
    before ->
      @result = browser.xpath("//a")

    it "should return result type node-set", ->
      assert.equal @result.type, "node-set"
    it "should return eleven nodes", ->
      assert.equal @result.value.length, 11
    it "should return first anchor", ->
      assert.equal @result.value[0].textContent, "First anchor"
    it "should return third anchor", ->
      assert.equal @result.value[2].textContent, "Third anchor"

  describe "evaluate with id", ->
    before ->
      @result = browser.xpath('//*[@id="post-2"]/h2')

    it "should return one node", ->
      assert.equal @result.value.length, 1
    it "should return second post title", ->
      assert.equal @result.value[0].textContent, "Second post"

  describe "evaluate number", ->
    before ->
      @result = browser.xpath("count(//a)")

    it "should return result type number", ->
      assert.equal @result.type, "number"
    it "should return number of nodes", ->
      assert.equal @result.value, 11

  describe "evaluate string", ->
    before ->
      @result = browser.xpath("'foobar'")

    it "should return result type string", ->
      assert.equal @result.type, "string"
    it "should return number of nodes", ->
      assert.equal @result.value, "foobar"

  describe "evaluate boolean", ->
    before ->
      @result = browser.xpath("2 + 2 = 4")

    it "should return result type boolean", ->
      assert.equal @result.type, "boolean"
    it "should return number of nodes", ->
      assert.equal @result.value, true


  after ->
    browser.destroy()
