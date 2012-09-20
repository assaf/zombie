{ assert, brains, Browser } = require("./helpers")


describe "Tabs", ->

  before (done)->
    brains.get "/tabs", (req, res)->
      res.send """
      <html>
        <title>Brains</title>
      </html>
      """
    brains.ready done

  before ->
    @browser = new Browser()
    @browser.open(name: "first")
    @browser.open(name: "second")
    @browser.open(name: "third")
    @browser.open()
    @browser.open("_blank")

  it "should have on tab for each open window", ->
    assert.equal @browser.tabs.length, 5

  it "should treat _blank as special name", ->
    names = @browser.tabs.map((w)-> w.name)
    assert.deepEqual names, ["first", "second", "third", "", ""]

  it "should allow finding window by index number", ->
    assert window = @browser.tabs[1]
    assert.equal window.name, "second"

  it "should allow finding window by name", ->
    assert window = @browser.tabs["third"]
    assert.equal window.name, "third"

  it "should not index un-named windows", ->
    assert !@browser.tabs[""]
    assert !@browser.tabs[null]
    assert !@browser.tabs[undefined]

  it "should be able to select current tab by name", ->
    @browser.tabs.current = "second"
    assert.equal @browser.window.name, "second"

  it "should be able to select current tab by index", ->
    @browser.tabs.current = 2
    assert.equal @browser.window.name, "third"

  it "should be able to select current tab from window", ->
    @browser.tabs.current = @browser.tabs[0]
    assert.equal @browser.window.name, "first"

  it "should provide index of currently selected tab", ->
    @browser.tabs.current = "second"
    assert.equal @browser.tabs.index, 1
    @browser.tabs.current = @browser.tabs[2]
    assert.equal @browser.tabs.index, 2

  it "should fire onfocus event when selecting new tab", (done)->
    browser = new Browser()
    browser.open(name: "first")
    browser.open(name: "second")
    browser.tabs[1].addEventListener "focus", ->
      done()
    browser.tabs.current = 1
    browser.wait()

  it "should fire onblur event when selecting new tab", (done)->
    browser = new Browser()
    browser.open(name: "first")
    browser.open(name: "second")
    browser.tabs.current = 1
    browser.tabs[1].addEventListener "blur", ->
      done()
    browser.tabs.current = 0
    browser.wait()

  it "should reuse open tab when opening window with same name", ->
    window = @browser.tabs.open(name: "second")
    assert.equal @browser.tabs.length, 5
    assert.equal @browser.tabs.index, 1
    assert.equal window, @browser.tabs.current

  it "should reuse open tab when opening window with same name and navigate", (done)->
    window = @browser.tabs.open(name: "third", url: "http://localhost:3003/tabs")
    assert.equal @browser.tabs.length, 5
    assert.equal @browser.tabs.index, 2
    @browser.wait =>
      try
        assert.equal window, @browser.tabs.current
        assert.equal @browser.url, "http://localhost:3003/tabs"
        assert.equal @browser.document.title, "Brains"
        done()
      catch error
        done(error)

  it "should allow closing window by name", ->
    @browser.tabs.close("second")
    assert.equal @browser.tabs.length, 4
    names = @browser.tabs.map((w)-> w.name)
    assert.deepEqual names, ["first", "third", "", ""]

  it "should allow closing window by index", ->
    @browser.tabs.close(2)
    assert.equal @browser.tabs.length, 3
    names = @browser.tabs.map((w)-> w.name)
    assert.deepEqual names, ["first", "third", ""]

  it "should select previous tab when closing open tab", ->
    browser = new Browser()
    browser.open(name: "first")
    browser.open(name: "second")
    browser.open(name: "third")
    browser.tabs.current = 1
    assert.equal browser.window.name, "second"
    browser.tabs.close()
    assert.equal browser.window.name, "first"
    browser.destroy()

  it "allow closing all windows", ->
    browser = new Browser()
    browser.open(name: "first")
    browser.open(name: "second")
    browser.open(name: "third")
    browser.tabs.closeAll()
    assert.equal browser.tabs.length, 0
    assert.equal browser.tabs.current, null
    assert.equal browser.tabs.index, -1
    browser.destroy()

  it "should only have properties for named windows", ->
    browser = new Browser()
    browser.open(name: "foo")
    browser.open(name: "bar")
    names = (window.name for window in browser.tabs)
    assert.deepEqual names, ["foo", "bar"]
    assert.deepEqual Object.keys(browser.tabs), [0, 1, "foo", "bar"]

  it "should not shadow property with same name", ->
    browser = new Browser()
    browser.open(name: "open")
    assert browser.tabs.open instanceof Function

  it "should be able to find any window by name", ->
    browser = new Browser()
    browser.open(name: "open")
    assert browser.tabs.find("open").browser

  it "should support enumeration", ->
    browser = new Browser()
    browser.open(name: "foo")
    browser.open(name: "bar")
    names = browser.tabs.map((window)-> window.name)
    assert.deepEqual names, ["foo", "bar"]

  describe "new browser", ->
    before ->
      @browser = new Browser()

    it "should have no open windows", ->
      assert !@browser.window
      assert.equal @browser.tabs.length, 0

