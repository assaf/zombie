{ assert, brains, Browser } = require("./helpers")


describe "Tabs", ->

  browser = null
  before (done)->
    browser = Browser.create()
    brains.ready(done)

  before ->
    brains.get "/tabs", (req, res)->
      res.send """
      <html>
        <title>Brains</title>
      </html>
      """

  before ->
    browser.open(name: "first")
    browser.open(name: "second")
    browser.open(name: "third")
    browser.open()
    browser.open("_blank")

  it "should have on tab for each open window", ->
    assert.equal browser.tabs.length, 5

  it "should treat _blank as special name", ->
    names = browser.tabs.map((w)-> w.name)
    assert.deepEqual names, ["first", "second", "third", "", ""]

  it "should allow finding window by index number", ->
    assert window = browser.tabs[1]
    assert.equal window.name, "second"

  it "should allow finding window by name", ->
    assert window = browser.tabs["third"]
    assert.equal window.name, "third"

  it "should not index un-named windows", ->
    assert !browser.tabs[""]
    assert !browser.tabs[null]
    assert !browser.tabs[undefined]

  it "should be able to select current tab by name", ->
    browser.tabs.current = "second"
    assert.equal browser.window.name, "second"

  it "should be able to select current tab by index", ->
    browser.tabs.current = 2
    assert.equal browser.window.name, "third"

  it "should be able to select current tab from window", ->
    browser.tabs.current = browser.tabs[0]
    assert.equal browser.window.name, "first"

  it "should provide index of currently selected tab", ->
    browser.tabs.current = "second"
    assert.equal browser.tabs.index, 1
    browser.tabs.current = browser.tabs[2]
    assert.equal browser.tabs.index, 2

  describe "selecting new tab", ->
    before (done)->
      browser.tabs.closeAll()
      browser.open(name: "first")
      browser.open(name: "second")
      browser.tabs[0].addEventListener "focus", ->
        done()
      browser.tabs.current = 0
      browser.wait()

    it "should fire onfocus event", ->
      assert(true)

  describe "selecting new tab", ->
    before (done)->
      browser.tabs.closeAll()
      browser.open(name: "first")
      browser.open(name: "second")
      browser.tabs.current = 1
      browser.tabs[1].addEventListener "blur", ->
        done()
      browser.tabs.current = 0
      browser.wait()

    it "should fire onblur event", ->
      assert(true)

  describe "opening window with same name", ->
    before ->
      browser.tabs.closeAll()
      browser.open(name: "first")
      browser.open(name: "second")
      browser.open(name: "third")
      @second = browser.tabs.open(name: "second")

    it "should reuse open tab", ->
      assert.equal browser.tabs.length, 3
      assert.equal browser.tabs.index, 1
      assert.equal @second, browser.tabs.current

    describe "and different URL", ->
      before (done)->
        @third = browser.tabs.open(name: "third", url: "http://localhost:3003/tabs")
        browser.wait(done)

      it "should reuse open tab", ->
        assert.equal browser.tabs.length, 3
        assert.equal browser.tabs.index, 2
        assert.equal @third, browser.tabs.current
      it "should navigate to new URL", ->
        browser.assert.url "http://localhost:3003/tabs"
        browser.assert.text "title", "Brains"

  describe "closing window by name", ->
    before ->
      browser.tabs.closeAll()
      browser.open(name: "first")
      browser.open(name: "second")
      browser.open(name: "third")
    before ->
      browser.tabs.close("second")

    it "should close named window", ->
      assert.equal browser.tabs.length, 2
      names = browser.tabs.map((w)-> w.name)
      assert.deepEqual names, ["first", "third"]
    
  describe "closing window by index", ->
    before ->
      browser.tabs.closeAll()
      browser.open(name: "first")
      browser.open(name: "second")
      browser.open(name: "third")
    before ->
      browser.tabs.close(1)

    it "should close named window", ->
      assert.equal browser.tabs.length, 2
      names = browser.tabs.map((w)-> w.name)
      assert.deepEqual names, ["first", "third"]

  describe "closing window", ->
    before ->
      browser.open(name: "first")
      browser.open(name: "second")
      browser.open(name: "third")
      browser.tabs.current = 1
      browser.tabs.close()

    it "should navigate to previous tab", ->
      assert.equal browser.tabs.index, 0
      assert.equal browser.window.name, "first"

  describe "closing all tabs", ->
    before ->
      browser.tabs.closeAll()
      browser.open(name: "first")
      browser.open(name: "second")
      browser.open(name: "third")
      browser.tabs.closeAll()

    it "should leave no tabs open", ->
      assert.equal browser.tabs.length, 0
      assert.equal browser.tabs.current, null
      assert.equal browser.tabs.index, -1


  describe "tabs array", ->
    before ->
      browser.tabs.closeAll()
      browser.open(name: "first")
      browser.open(name: "second")
      browser.open()

    it "should have keys for named windows and their index", ->
      assert.deepEqual Object.keys(browser.tabs), [0, 1, 2, "first", "second"]

    it "should allow iterating through all windows", ->
      names = (window.name for window in browser.tabs)
      assert.deepEqual names, ["first", "second", ""]

    it "should allow enumeration of all windows", ->
      names = browser.tabs.map((window)-> window.name)
      assert.deepEqual names, ["first", "second", ""]

    it "should not shadow property with same name", ->
      browser.open(name: "open")
      assert browser.tabs.open instanceof Function

    it "should be able to find any window by name", ->
      assert browser.tabs.find("open").browser


  after ->
    browser.destroy()


  describe "new browser", ->
    newBrowser = null
    before ->
      newBrowser = Browser.create()

    it "should have no open windows", ->
      assert !newBrowser.window
      assert.equal newBrowser.tabs.length, 0

    after ->
      newBrowser.destroy()
