{ brains, Browser } = require("./helpers")

describe "Document", ->

  describe "activeElement", ->
    before (done)->
      brains.get "/document/activeElement", (req, res)->
        res.send """
        <html>
        </html>
        """
      brains.ready done

    before (done)->
      @browser = new Browser()
      @browser.visit("/document/activeElement", done)

    it "should be document body", ->
      @browser.assert.hasFocus undefined

    describe "autofocus on div", ->
      before (done)->
        div = @browser.document.createElement("div")
        div.setAttribute("autofocus")
        @browser.document.body.appendChild(div)
        @browser.wait(done)

      it "should not change active element", ->
        @browser.assert.hasFocus undefined

    describe "autofocus on input", ->
      before (done)->
        @input = @browser.document.createElement("input")
        @input.setAttribute("autofocus")
        @browser.document.body.appendChild(@input)
        @browser.wait(done)

      it "should change active element", ->
        @browser.assert.hasFocus @input

    describe "autofocus on textarea", ->
      before (done)->
        @textarea = @browser.document.createElement("textarea")
        @textarea.setAttribute("autofocus")
        @browser.document.body.appendChild(@input)
        @browser.wait(done)

      it "should change active element", ->
        @browser.assert.hasFocus @textarea

    describe "focus on div", ->
      before (done)->
        @browser.reload(done)
      before (done)->
        div = @browser.document.createElement("div")
        @browser.document.body.appendChild(div)
        div.focus()
        @browser.wait(done)

      it "should change active element", ->
        @browser.assert.hasFocus undefined

    describe "focus on input", ->
      before (done)->
        @browser.reload(done)
      before (done)->
        @input = @browser.document.createElement("input")
        @browser.document.body.appendChild(@input)
        @input.focus()
        @browser.wait(done)

      it "should change active element", ->
        @browser.assert.hasFocus @input

    describe "focus on textarea", ->
      before (done)->
        @browser.reload(done)
      before (done)->
        @textarea = @browser.document.createElement("input")
        @browser.document.body.appendChild(@textarea)
        @textarea.focus()
        @browser.wait(done)

      it "should change active element", ->
        @browser.assert.hasFocus @textarea

  after ->
    @browser.destroy()
