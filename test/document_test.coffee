{ assert, brains, Browser } = require("./helpers")

describe "Document", ->

  browser = null
  before (done)->
    browser = Browser.create()
    brains.ready(done)


  describe "character encoding", ->
    before ->
      brains.get "/document/encoding", (req, res)->
        res.header("Content-Type", "text/html; charset=greek")
        res.send """
        <html>
          <body>\xc3\xe5\xe9\xdc!</body>
        </html>
        """
    before (done)->
      browser.visit("/document/encoding", done)

    it "should support greek8", ->
      browser.assert.text "body", "Γειά!"


  describe "activeElement", ->
    before ->
      brains.get "/document/activeElement", (req, res)->
        res.send """
        <html>
          <body></body>
        </html>
        """

    before (done)->
      browser.visit("/document/activeElement", done)

    it "should be document body", ->
      browser.assert.hasFocus undefined

    describe "autofocus on div", ->
      before (done)->
        browser.visit("/document/activeElement", done)
      before ->
        div = browser.document.createElement("div")
        div.setAttribute("autofocus")
        browser.document.body.appendChild(div)

      it "should not change active element", ->
        browser.assert.hasFocus undefined

    describe "autofocus on input", ->
      before (done)->
        browser.visit("/document/activeElement", done)
      before ->
        @input = browser.document.createElement("input")
        @input.setAttribute("autofocus")
        browser.document.body.appendChild(@input)

      it "should change active element", ->
        browser.assert.hasFocus @input

    describe "autofocus on textarea", ->
      before (done)->
        browser.visit("/document/activeElement", done)
      before ->
        @textarea = browser.document.createElement("textarea")
        @textarea.setAttribute("autofocus")
        browser.document.body.appendChild(@textarea)

      it "should change active element", ->
        browser.assert.hasFocus @textarea


    describe "focus on div", ->
      before (done)->
        browser.visit("/document/activeElement", done)
      before ->
        div = browser.document.createElement("div")
        browser.document.body.appendChild(div)
        div.focus()

      it "should change active element", ->
        browser.assert.hasFocus undefined

    describe "focus on input", ->
      before (done)->
        browser.visit("/document/activeElement", done)
      before ->
        @input = browser.document.createElement("input")
        browser.document.body.appendChild(@input)
        @input.focus()

      it "should change active element", ->
        browser.assert.hasFocus @input

    describe "focus on textarea", ->
      before (done)->
        browser.visit("/document/activeElement", done)
      before ->
        @textarea = browser.document.createElement("input")
        browser.document.body.appendChild(@textarea)
        @textarea.focus()

      it "should change active element", ->
        browser.assert.hasFocus @textarea

  describe "insertAdjacentHTML", ->
    before ->
      brains.get "/document/insertAdjacentHTML", (req, res)->
        res.send "<html><body><div><p id='existing'></p></div></body></html>"

    before (done)->
      browser.visit("/document/insertAdjacentHTML", done)

    describe "beforebegin", ->
      before ->
        @div = browser.query("div")
        @div.insertAdjacentHTML("beforebegin", "<p id='beforebegin'></p>")

      it "should insert content before target element", ->
        assert.equal browser.body.firstChild.getAttribute("id"), "beforebegin"

    describe "afterbegin", ->
      before ->
        @div.insertAdjacentHTML("afterbegin", "<p id='afterbegin'></p>")

      it "should insert content as the first child within target element", ->
        assert.equal @div.firstChild.getAttribute("id"), "afterbegin"

    describe "beforeend", ->
      before ->
        @div.insertAdjacentHTML("beforeend", "<p id='beforeend'></p>")

      it "should insert content as the last child within target element", ->
        assert.equal @div.lastChild.getAttribute("id"), "beforeend"

    describe "afterend", ->
      before ->
        @div.insertAdjacentHTML("afterend", "<p id='afterend'></p>")

      it "should insert content after the target element", ->
        assert.equal browser.body.lastChild.getAttribute("id"), "afterend"

  after ->
    browser.destroy()
