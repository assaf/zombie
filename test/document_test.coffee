{ brains, Browser } = require("./helpers")

describe "Document", ->

  browser = null
  before (done)->
    browser = Browser.create()
    brains.ready(done)

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


  after ->
    browser.destroy()
