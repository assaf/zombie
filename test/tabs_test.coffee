{ assert, brains, Browser } = require("./helpers")


describe "Tabs", ->

  before ->
    @browser = new Browser(name: "first")
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
    @browser.tabs.current = 0
    @browser.tabs[1].addEventListener "focus", ->
      done()
      done = null # will be called multiple times from other tests
    @browser.tabs.current = 1

  it "should fire onblur event when selecting new tab", (done)->
    @browser.tabs.current = 0
    @browser.tabs[0].addEventListener "blur", ->
      done()
      done = null # will be called multiple times from other tests
    @browser.tabs.current = 2

  it "should reuse open tab when opening window with same name", ->
    window = @browser.tabs.open(name: "second")
    assert.equal @browser.tabs.length, 5
    assert.equal @browser.tabs.index, 1
    assert.equal window, @browser.tabs.current

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
    @browser.tabs.current = 1
    assert.equal @browser.window.name, "third"
    @browser.tabs.close()
    assert.equal @browser.window.name, "first"

  it "allow closing all windows", ->
    assert.equal @browser.tabs.length, 2
    @browser.tabs.closeAll()
    assert.equal @browser.tabs.length, 0
    assert.equal @browser.tabs.current, null
    assert.equal @browser.tabs.index, -1

