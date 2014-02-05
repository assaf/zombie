{ assert, brains, Browser } = require("./helpers")
File    = require("fs")
Crypto  = require("crypto")


describe "Forms", ->

  browser = null
  before (done)->
    browser = Browser.create()
    brains.ready(done)

  before ->
    brains.get "/forms/form", (req, res)->
      res.send """
      <html>
        <body>
          <form action="/forms/submit" method="post">
            <label>Name <input type="text" name="name" id="field-name" /></label>
            <label for="field-email">Email</label>
            <input type="text" name="email" id="field-email"></label>
            <textarea name="likes" id="field-likes">Warm brains</textarea>
            <input type="password" name="password" id="field-password">
            <input type="badtype" name="invalidtype" id="field-invalidtype">
            <input type="text" name="email2" id="field-email2">
            <input type="text" name="email3" id="field-email3">
            <input type="text" name="disabled" disabled>
            <input type="text" name="readonly" readonly>
            <input type="text" name="empty_text" id="empty-text">

            <label>Hungry</label>
            <label>You bet<input type="checkbox" name="hungry[]" value="you bet" id="field-hungry"></label>
            <label>Certainly<input type="checkbox" name="hungry[]" value="certainly" id="field-hungry-certainly"></label>

            <label for="field-brains">Brains?</label>
            <input type="checkbox" name="brains" value="yes" id="field-brains">
            <input type="checkbox" name="green" id="field-green" value="Super green!" checked="checked">
            <input type="checkbox" name="check" id="field-check" value="Huh?" checked="checked">
            <input type="checkbox" name="uncheck" id="field-uncheck" value="Yeah!">
            <input type="checkbox" name="empty_checkbox" id="empty-checkbox" checked="checked">

            <label>Looks
              <select name="looks" id="field-looks">
                <option value="blood" label="Bloody"></option>
                <option value="clean" label="Clean"></option>
                <option value=""      label="Choose one"></option>
              </select>
            </label>
            <label>Scary <input name="scary" type="radio" value="yes" id="field-scary"></label>
            <label>Not scary <input name="scary" type="radio" value="no" id="field-notscary" checked="checked"></label>

            <select name="state" id="field-state">
              <option>alive</option>
              <option>dead</option>
              <option>neither</option>
            </select>

            <span>First address</span>
            <label for='address1_street'>Street</label>
            <input type="text" name="addresses[][street]" value="" id="address1_street">

            <label for='address1_city'>City</label>
            <input type="text" name="addresses[][city]" value="" id="address1_city">

            <span>Second address</span>
            <label for='address2_street'>Street</label>
            <input type="text" name="addresses[][street]" value="" id="address2_street">

            <label for='address2_city'>City</label>
            <input type="text" name="addresses[][city]" value="" id="address2_city">

            <select name="kills" id="field-kills">
              <option>Five</option>
              <option>Seventeen</option>
              <option id="option-killed-thousands">Thousands</option>
            </select>

            <select name="unselected_state" id="field-unselected-state">
              <option>alive</option>
              <option>dead</option>
            </select>

            <select name="hobbies[]" id="field-hobbies" multiple="multiple">
              <option>Eat Brains</option>
              <option id="hobbies-messy">Make Messy</option>
              <option>Sleep</option>
            </select>

            <select name="months" id="field-months">
              <option value=""></option>
              <option value="jan_2011"> Jan 2011 </option>
              <option value="feb_2011"> Feb 2011 </option>
              <option value="mar_2011"> Mar 2011 </option>
            </select>

            <input type="unknown" name="unknown" value="yes">
            <input type="reset" value="Reset">
            <input type="submit" name="button" value="Submit">
            <input type="image" name="image" id="image_submit" value="Image Submit">

            <button name="button" value="hit-me">Hit Me</button>

            <input type="checkbox" id="field-prevent-check">
            <input type="radio" id="field-prevent-radio">
          </form>
          <div id="formless_inputs">
            <label>Hunter <input type="text" name="hunter_name" id="hunter-name"></label>
            <textarea name="hunter_hobbies">Killing zombies.</textarea>
            <input type="password" name="hunter_password" id="hunter-password">
            <input type="badtype" name="hunter_invalidtype" id="hunter-invalidtype" />
            <label>Weapons</label>
            <label>Chainsaw<input type="checkbox" name="hunter_weapon[]" value="chainsaw"></label>
            <label>Shotgun<input type="checkbox" name="hunter_weapon[]" value="shotgun"></label>
            <label>Type
              <select name="hunter_type">
                <option value="regular" label="Regular"></option>
                <option value="evil" label="Evil"></option>
                <option value="tiny" label="tiny"></option>
              </select>
            </label>
            <label>Powerglove <input name="hunter_powerglove" type="radio" value="glove"></label>
            <label>No powerglove <input name="hunter_powerglove" type="radio" value="noglove" checked="checked"></label>
          </div>
        </body>
      </html>
      """

    brains.post "/forms/submit", (req, res)->
      res.send """
      <html>
        <title>Results</title>
        <body>
          <div id="name">#{req.body.name}</div>
          <div id="likes">#{req.body.likes}</div>
          <div id="green">#{req.body.green}</div>
          <div id="brains">#{req.body.brains}</div>
          <div id="looks">#{req.body.looks}</div>
          <div id="hungry">#{JSON.stringify(req.body.hungry)}</div>
          <div id="scary">#{req.body.scary}</div>
          <div id="state">#{req.body.state}</div>
          <div id="empty-text">#{req.body.empty_text}</div>
          <div id="empty-checkbox">#{req.body.empty_checkbox || "nothing"}</div>
          <div id="unselected_state">#{req.body.unselected_state}</div>
          <div id="hobbies">#{JSON.stringify(req.body.hobbies)}</div>
          <div id="addresses">#{JSON.stringify(req.body.addresses)}</div>
          <div id="unknown">#{req.body.unknown}</div>
          <div id="clicked">#{req.body.button}</div>
          <div id="image_clicked">#{req.body.image}</div>
        </body>
      </html>
      """


  describe "fill field", ->
    before (done)->
      browser.visit "/forms/form", =>
        fill_events = ["input", "change"]
        count = fill_events.length
        browser.on "event", (event, target)=>
          if event.type in fill_events
            count -= 1
            if count == 0
              @changed = target
              count = fill_events.length
        done()

    describe "fill input with same the same value", ->
      before ->
        browser.fill("Name", "")
      it "should not fire input *and* change events", ->
        assert.equal @change, undefined

    describe "text input enclosed in label", ->
      before ->
        browser.fill("Name", "ArmBiter")

      it "should set text field", ->
        browser.assert.input "#field-name", "ArmBiter"
      it "should fire input and changed event", ->
        assert.equal @changed.id, "field-name"

    describe "email input referenced from label", ->
      before ->
        browser.fill("Email", "armbiter@example.com")

      it "should set email field", ->
        browser.assert.input "#field-email", "armbiter@example.com"
      it "should fire input and change events", ->
        assert.equal @changed.id, "field-email"

    describe "textarea by field name", ->
      before ->
        browser.fill("likes", "Arm Biting")

      it "should set textarea", ->
        browser.assert.input "#field-likes", "Arm Biting"
      it "should fire input and change events", ->
        assert.equal @changed.id, "field-likes"

    describe "password input by selector", ->
      before ->
        browser.fill("input[name=password]", "b100d")

      it "should set password", ->
        browser.assert.input "#field-password", "b100d"
      it "should fire input and change events", ->
        assert.equal @changed.id, "field-password"

    describe "input without a valid type", ->
      before ->
        browser.fill("input[name=invalidtype]", "some value")

      it "should set value", ->
        browser.assert.input "#field-invalidtype", "some value"
      it "should fire input and change events", ->
        assert.equal @changed.id, "field-invalidtype"

    describe "email2 input by node", ->
      before ->
        browser.fill("#field-email2", "headchomper@example.com")

      it "should set email2 field", ->
        browser.assert.input "#field-email2", "headchomper@example.com"
      it "should fire input and change events", ->
        assert.equal @changed.id, "field-email2"

    describe "disabled input can not be modified", ->
      it "should raise error", ->
        assert.throws ->
          browser.fill("#disabled_input_field", "yeahh")

    describe "readonly input can not be modified", ->
      it "should raise error", ->
        assert.throws ->
          browser.fill("#readonly_input_field", "yeahh")

    describe "focus field (1)", ->
      before (done)->
        browser.visit("/forms/form")
          .then ->
            field1 = browser.querySelector("#field-email2")
            field2 = browser.querySelector("#field-email3")
            browser.fill(field1, "something")
            field2.addEventListener "focus", ->
              done()
            browser.fill(field2, "else")

      it "should fire focus event on selected field", ->
        assert true

    describe "focus field (2)", ->
      before (done)->
        browser.visit("/forms/form")
          .then ->
            field1 = browser.querySelector("#field-email2")
            field2 = browser.querySelector("#field-email3")
            browser.fill field1, "something"
            field1.addEventListener "blur", ->
              done()
            browser.fill field2, "else"

      it "should fire blur event on previous field", ->
        assert true

    describe "keep value and switch focus", ->
      before (done)->
        browser.visit("/forms/form")
          .then ->
            field1 = browser.querySelector("#field-email2")
            field2 = browser.querySelector("#field-email3")
            field1.addEventListener "change", ->
              done(new Error("Should not fire"))

            browser.focus(field1)
            browser.focus(field2)
            setImmediate(done)

      it "should fire change event on previous field", ->
        assert true

    describe "change value and switch focus", ->
      before (done)->
        browser.visit("/forms/form")
          .then ->
            field1 = browser.querySelector("#field-email2")
            field2 = browser.querySelector("#field-email3")
            field1.addEventListener "change", ->
              done()

            browser.focus(field1)
            field1.value = "something"
            browser.focus(field2)

      it "should fire change event on previous field", ->
        assert true


  describe "check box", ->
    before (done)->
      browser.visit "/forms/form", =>
        browser.on "event", (event, target)=>
          switch event.type
            when "change"
              @changed = target
            when "click"
              @clicked = target
        done()

    describe "checkbox enclosed in label", ->
      before ->
        @changed = @clicked = null
        browser.check("You bet")

      it "should check checkbox", ->
        browser.assert.element "#field-hungry:checked"
      it "should fire change event", ->
        assert.equal @changed.id, "field-hungry"
      it "should fire clicked event", ->
        assert.equal @clicked.id, "field-hungry"

      describe "with callback", ->
        before ->
          browser.check("Brains?")

        it "should callback", ->
          browser.assert.element "#field-brains:checked"

    describe "checkbox referenced from label", ->
      before ->
        browser.uncheck("Brains?")
        @changed = @clicked = null
        browser.check("Brains?")

      it "should check checkbox", ->
        browser.assert.element "#field-brains:checked"
      it "should fire change event", ->
        assert.equal @changed.id, "field-brains"

      describe "uncheck with callback", ->
        before (done)->
          browser.visit "/forms/form", ->
            browser
              .check("Brains?")
              .uncheck("Brains?")
            done()

        it "should callback", ->
          browser.assert.elements "#field-brains:checked", 0

    describe "checkbox by name", ->
      before ->
        browser.check("green")
        @changed = @clicked = null
        browser.uncheck("green")

      it "should uncheck checkbox", ->
        browser.assert.elements "#field-green:checked", 0
      it "should fire change event", ->
        assert.equal @changed.id, "field-green"

    describe "check callback", ->
      before ->
        browser.check("uncheck")

      it "should callback", ->
        browser.assert.elements "#field-uncheck:checked", 1

    describe "uncheck callback", ->
      before ->
        browser.uncheck("check")

      it "should callback", ->
        browser.assert.elements "#field-uncheck:checked", 1

    describe "prevent default", ->
      values = []

      before ->
        checkBox = browser.$$("#field-prevent-check")
        values.push(checkBox.checked)
        checkBox.addEventListener "click", (event)->
          values.push(checkBox.checked)
          event.preventDefault()
        browser.check(checkBox)
        values.push(checkBox.checked)

      it "should turn checkbox on then off", ->
        assert.deepEqual values, [false, true, false]

    describe "any checkbox (1)", ->
      before (done)->
        browser.visit "/forms/form", ->
          field1 = browser.querySelector("#field-check")
          field2 = browser.querySelector("#field-uncheck")
          browser.uncheck(field1)
          browser.check(field1)
          field2.addEventListener "focus", ->
            done()
          browser.check(field2)

      it "should fire focus event on selected field", ->
        assert true

    describe "any checkbox (2)", ->
      before (done)->
        browser.visit "/forms/form", ->
          field1 = browser.querySelector("#field-check")
          field2 = browser.querySelector("#field-uncheck")
          browser.uncheck(field1)
          browser.check(field1)
          field1.addEventListener "blur", ->
            done()
          browser.check(field2)

      it "should fire blur event on previous field", ->
        assert true


  describe "radio buttons", ->
    before (done)->
      browser.visit "/forms/form", =>
        browser.on "event", (event, target)=>
          switch event.type
            when "change"
              @changed = target
            when "click"
              @clicked = target
        done()

    describe "radio button enclosed in label", ->
      before ->
        browser.choose("Scary")

      it "should check radio", ->
        browser.assert.element "#field-scary:checked"
      it "should fire click event", ->
        assert.equal @clicked.id, "field-scary"
      it "should fire change event", ->
        assert.equal @changed.id, "field-scary"

      describe "with callback", ->
        before (done)->
          browser.visit "/forms/form", ->
            browser.choose("Scary")
            done()

        it "should callback", ->
          browser.assert.element "#field-scary:checked"

    describe "radio button by value", ->
      before (done)->
        browser.visit "/forms/form", ->
          browser.choose("no")
          done()

      it "should check radio", ->
        browser.assert.element "#field-notscary:checked"
      it "should uncheck other radio", ->
        browser.assert.elements "#field-scary:checked", 0

    describe "prevent default", ->
      values = []

      before ->
        radio = browser.$$("#field-prevent-radio")
        values.push(radio.checked)
        radio.addEventListener "click", (event)->
          values.push(radio.checked)
          event.preventDefault()
        browser.choose(radio)
        values.push(radio.checked)

      it "should turn radio on then off", ->
        assert.deepEqual values, [false, true, false]

    describe "any radio button (1) ", ->
      before ->
        field1 = browser.querySelector("#field-scary")
        field2 = browser.querySelector("#field-notscary")
        browser.choose(field1)
        field2.addEventListener "focus", ->
          done()
        browser.choose(field2)

      it "should fire focus event on selected field", ->
        assert true

    describe "any radio button (1) ", ->
      before ->
        field1 = browser.querySelector("#field-scary")
        field2 = browser.querySelector("#field-notscary")
        browser.choose(field1)
        field1.addEventListener "blur", ->
          done()
        browser.choose(field2)

      it "should fire blur event on previous field", ->
        assert true


  describe "select option", ->
    before (done)->
      browser.visit "/forms/form", =>
        browser.on "event", (event, target)=>
          if event.type == "change"
            @changed = target
        done()

    describe "enclosed in label using option label", ->
      before ->
        browser.select("Looks", "Bloody")

      it "should set value", ->
        browser.assert.input "#field-looks", "blood"
      it "should select first option", ->
        selected = (!!option.getAttribute("selected") for option in browser.querySelector("#field-looks").options)
        assert.deepEqual selected, [true, false, false]
      it "should fire change event", ->
        assert.equal @changed.id, "field-looks"

    describe "select name using option value", ->
      before ->
        browser.select("state", "dead")

      it "should set value", ->
        browser.assert.input "#field-state", "dead"
      it "should select second option", ->
        selected = (!!option.getAttribute("selected") for option in browser.querySelector("#field-state").options)
        assert.deepEqual selected, [false, true, false]
      it "should fire change event", ->
        assert.equal @changed.id, "field-state"

    describe "select name using option text", ->
      before ->
        browser.select("months", "Jan 2011")

      it "should set value", ->
        browser.assert.input "#field-months", "jan_2011"
      it "should select second option", ->
        selected = (!!option.getAttribute("selected") for option in browser.querySelector("#field-months").options)
        assert.deepEqual selected, [false, true, false, false]
      it "should fire change event", ->
        assert.equal @changed.id, "field-months"

    describe "select option value directly", ->
      before ->
        browser.selectOption("#option-killed-thousands")

      it "should set value", ->
        browser.assert.input "#field-kills", "Thousands"
      it "should select second option", ->
        selected = (!!option.getAttribute("selected") for option in browser.querySelector("#field-kills").options)
        assert.deepEqual selected, [false, false, true]
      it "should fire change event", ->
        assert.equal @changed.id, "field-kills"

    describe "select callback", ->
      before (done)->
        browser.visit "/forms/form", ->
          browser.select("unselected_state", "dead")
          done()

      it "should callback", ->
        browser.assert.input "#field-unselected-state", "dead"

    describe "select option callback", ->
      before (done)->
        browser.visit "/forms/form", ->
          browser.selectOption("#option-killed-thousands")
          done()

      it "should callback", ->
        browser.assert.input "#field-kills", "Thousands"

    describe "any selection (1)", ->
      before (done)->
        browser.visit "/forms/form", ->
          field1 = browser.querySelector("#field-email2")
          field2 = browser.querySelector("#field-kills")
          browser.fill(field1, "something")
          field2.addEventListener "focus", ->
            done()
          browser.select(field2, "Five")

      it "should fire focus event on selected field", ->
        assert true

    describe "any selection (2)", ->
      before (done)->
        browser.visit "/forms/form", ->
          field1 = browser.querySelector("#field-email2")
          field2 = browser.querySelector("#field-kills")
          browser.fill(field1, "something")
          field1.addEventListener "blur", ->
            done()
          browser.select(field2, "Five")

      it "should fire blur event on previous field", ->
        assert true


  describe "multiple select option", ->
    before (done)->
      browser.visit "/forms/form", =>
        browser.on "event", (event, target)=>
          if event.type == "change"
            @changed = target
        done()

    describe "select name using option value", ->
      before ->
        browser.select("#field-hobbies", "Eat Brains")
        browser.select("#field-hobbies", "Sleep")

      it "should select first and second options", ->
        selected = (!!option.getAttribute("selected") for option in browser.querySelector("#field-hobbies").options)
        assert.deepEqual selected, [true, false, true]
      it "should fire change event", ->
        assert.equal @changed.id, "field-hobbies"
      it "should not fire change event if nothing changed", ->
        assert @changed
        @changed = null
        browser.select("#field-hobbies", "Eat Brains")
        assert !@changed

    describe "unselect name using option value", ->
      before (done)->
        browser.visit("/forms/form")
          .then ->
            browser.select("#field-hobbies", "Eat Brains")
            browser.select("#field-hobbies", "Sleep")
            browser.unselect("#field-hobbies", "Sleep")
            return
          .then(done, done)

      it "should unselect items", ->
        selected = (!!option.getAttribute("selected") for option in browser.querySelector("#field-hobbies").options)
        assert.deepEqual selected, [true, false, false]

	  describe "unselect name using option selector", ->
      before (done)->
        browser.visit("/forms/form")
          .then ->
            browser.selectOption("#hobbies-messy")
            browser.unselectOption("#hobbies-messy")
            return
          .then(done, done)

      it "should unselect items", ->
        assert !browser.query("#hobbies-messy").selected

    describe "with callback", ->
      before (done)->
        browser.visit "/forms/form", ->
          browser.unselect("#field-hobbies", "Eat Brains")
          browser.unselect("#field-hobbies", "Sleep")
          browser.select("#field-hobbies", "Eat Brains")
          done()

      it "should unselect callback", ->
        selected = (!!option.getAttribute("selected") for option in browser.querySelector("#field-hobbies").options)
        assert.deepEqual selected, [true, false, false]


  describe "fields not contained in a form", ->
    before (done)->
      browser.visit("/forms/form", done)

    it "should not fail", ->
      browser
        .fill("Hunter", "Bruce")
        .fill("hunter_hobbies", "Trying to get home")
        .fill("#hunter-password", "klaatubarada")
        .fill("input[name=hunter_invalidtype]", "necktie?")
        .check("Chainsaw")
        .choose("Powerglove")
        .select("Type", "Evil")


  describe "reset form", ->

    describe "by calling reset", ->

      before (done)->
        browser.visit("/forms/form")
          .then ->
            browser
              .fill("Name", "ArmBiter")
              .fill("likes", "Arm Biting")
              .check("You bet")
              .choose("Scary")
              .select("state", "dead")
            browser.querySelector("form").reset()
            return
          .then(done, done)

      it "should reset input field to original value", ->
        browser.assert.input "#field-name", ""
      it "should reset textarea to original value", ->
        browser.assert.input "#field-likes", "Warm brains"
      it "should reset checkbox to original value", ->
        browser.assert.elements "#field-hungry:checked", 0
      it "should reset radio to original value", ->
        browser.assert.elements "#field-scary:checked", 0
        browser.assert.elements "#field-notscary:checked", 1
      it "should reset select to original option", ->
        browser.assert.input "#field-state", "alive"

    describe "with event handler", ->
      eventType = null

      before (done)->
        browser.visit("/forms/form")
          .then ->
            browser.querySelector("form [type=reset]").addEventListener "click", (event)->
              eventType = event.type
              done()
          .then ->
            browser.querySelector("form [type=reset]").click()

      it "should fire click event", ->
        assert.equal eventType, "click"

    describe "with preventDefault", ->
      before (done)->
        browser.visit("/forms/form")
          .then ->
            browser.fill("Name", "ArmBiter")
            browser.querySelector("form [type=reset]").addEventListener "click", (event)->
              event.preventDefault()
          .then ->
            browser.querySelector("form [type=reset]").click()
          .then(done, done)

      it "should not reset input field", ->
        browser.assert.input "#field-name", "ArmBiter"

    describe "by clicking reset input", ->
      before (done)->
        browser.visit("/forms/form")
          .then ->
            browser.fill("Name", "ArmBiter")
            browser.querySelector("form [type=reset]").click()
          .then(done, done)

      it "should reset input field to original value", ->
        browser.assert.input "#field-name", ""


  # Submitting form
  describe "submit form", ->

    describe "by calling submit", ->
      before (done)->
        browser.visit("/forms/form")
          .then ->
            browser
              .fill("Name", "ArmBiter")
              .fill("likes", "Arm Biting")
              .check("You bet")
              .check("Certainly")
              .choose("Scary")
              .select("state", "dead")
              .select("looks", "Choose one")
              .select("#field-hobbies", "Eat Brains")
              .select("#field-hobbies", "Sleep")
              .check("Brains?")
              .fill('#address1_city', 'Paris')
              .fill('#address1_street', 'CDG')
              .fill('#address2_city', 'Mikolaiv')
              .fill('#address2_street', 'PGS')
            browser.querySelector("form").submit()
            browser.wait()
          .then(done, done)

      it "should open new page", ->
        browser.assert.url "http://localhost:3003/forms/submit"
        browser.assert.text "title", "Results"
      it "should add location to history", ->
        assert.equal browser.window.history.length, 2
      it "should send text input values to server", ->
        browser.assert.text "#name", "ArmBiter"
      it "should send textarea values to server", ->
        browser.assert.text "#likes", "Arm Biting"
      it "should send radio button to server", ->
        browser.assert.text "#scary", "yes"
      it "should send unknown types to server", ->
        browser.assert.text "#unknown", "yes"
      it "should send checkbox with default value to server (brains)", ->
        browser.assert.text "#brains", "yes"
      it "should send checkbox with default value to server (green)", ->
        browser.assert.text "#green", "Super green!"
      it "should send multiple checkbox values to server", ->
        browser.assert.text "#hungry", '["you bet","certainly"]'
      it "should send selected option to server", ->
        browser.assert.text "#state", "dead"
      it "should send first selected option if none was chosen to server", ->
        browser.assert.text "#unselected_state", "alive"
        browser.assert.text "#looks", ""
      it "should send multiple selected options to server", ->
        browser.assert.text "#hobbies", '["Eat Brains","Sleep"]'
      it "should send empty text fields", ->
        browser.assert.text "#empty-text", ""
      it "should send checked field with no value", ->
        browser.assert.text "#empty-checkbox", "1"


    describe "by clicking button", ->
      before (done)->
        browser.visit("/forms/form")
          .then ->
            browser
              .fill("Name", "ArmBiter")
              .fill("likes", "Arm Biting")
            return browser.pressButton("Hit Me")
          .then(done, done)

      it "should open new page", ->
        browser.assert.url "http://localhost:3003/forms/submit"
      it "should add location to history", ->
        assert.equal browser.window.history.length, 2
      it "should send button value to server", ->
        browser.assert.text "#clicked", "hit-me"
      it "should send input values to server", ->
        browser.assert.text "#name", "ArmBiter"
        browser.assert.text "#likes", "Arm Biting"
      it "should not send other button values to server", ->
        browser.assert.text "#image_clicked", "undefined"

    describe "pressButton(1)", ->
      before (done)->
        browser.visit "/forms/form", ->
          field = browser.querySelector("#field-email2")
          browser.fill(field, "something")
          browser.button("Hit Me").addEventListener "focus", ->
            done()
          browser.pressButton("Hit Me")

      it "should fire focus event on button", ->
        assert true

    describe "pressButton(2)", ->
      before (done)->
        browser.visit "/forms/form", ->
          field = browser.querySelector("#field-email2")
          browser.fill(field, "something")
          field.addEventListener "blur", ->
            done()
          browser.pressButton("Hit Me")

      it "should fire blur event on previous field", ->
        assert true


    describe "by clicking image button", ->
      before (done)->
        browser.visit "/forms/form", ->
          browser
            .fill("Name", "ArmBiter")
            .fill("likes", "Arm Biting")
            .pressButton("#image_submit", done)

      it "should open new page", ->
        browser.assert.url "http://localhost:3003/forms/submit"
      it "should add location to history", ->
        assert.equal browser.window.history.length, 2
      it "should send image value to server", ->
        browser.assert.text "#image_clicked", "Image Submit"
      it "should send input values to server", ->
        browser.assert.text "#name", "ArmBiter"
        browser.assert.text "#likes", "Arm Biting"
      it "should not send other button values to server", ->
        browser.assert.text "#clicked", "undefined"

    describe "by clicking input", ->
      before (done)->
        browser.visit "/forms/form", ->
          browser
            .fill("Name", "ArmBiter")
            .fill("likes", "Arm Biting")
            .pressButton("Submit", done)

      it "should open new page", ->
        browser.assert.url "http://localhost:3003/forms/submit"
      it "should add location to history", ->
        assert.equal browser.window.history.length, 2
      it "should send submit value to server", ->
        browser.assert.text "#clicked", "Submit"
      it "should send input values to server", ->
        browser.assert.text "#name", "ArmBiter"
        browser.assert.text "#likes", "Arm Biting"

    describe "cancel event", ->
      before (done)->
        brains.get "/forms/cancel", (req, res)->
          res.send """
          <html>
            <head>
              <script src="/jquery.js"></script>
              <script>
                $(function() {
                  $("form").submit(function() {
                    return false;
                  })
                })
              </script>
            </head>
            <body>
              <form action="/forms/submit" method="post">
                <button>Submit</button>
              </form>
            </body>
          </html>
          """

        browser.visit "/forms/cancel", ->
          browser.pressButton("Submit", done)

      it "should not change page", ->
        browser.assert.url "http://localhost:3003/forms/cancel"


  # File upload
  describe "file upload", ->
    before ->
      brains.get "/forms/upload", (req, res)->
        res.send """
        <html>
          <body>
            <form method="post" enctype="multipart/form-data">
              <input name="text" type="file">
              <input name="image" type="file">
              <button>Upload</button>
            </form>
          </body>
        </html>
        """

      brains.post "/forms/upload", (req, res)->
        if req.files
          [text, image] = [req.files.text, req.files.image]
          if text || image
            data = File.readFileSync((text || image).path)
            if image
              digest = Crypto.createHash("md5").update(data).digest("hex")
            res.send """
            <html>
              <head><title>#{(text || image).name}</title></head>
              <body>#{digest || data}</body>
            </html>
            """
            return

        res.send "<html><body>nothing</body></html>"


    describe "text", ->
      before (done)->
        browser.visit "/forms/upload", ->
          filename = __dirname + "/data/random.txt"
          browser
            .attach("text", filename)
            .pressButton("Upload", done)

      it "should upload file", ->
        browser.assert.text "body", "Random text"
      it "should upload include name", ->
        browser.assert.text "title", "random.txt"


    describe "binary", ->
      filename = __dirname + "/data/zombie.jpg"

      before (done)->
        browser.visit "/forms/upload", ->
          browser
            .attach("image", filename)
            .pressButton("Upload", done)

      it "should upload include name", ->
        browser.assert.text "title", "zombie.jpg"
      it "should upload file", ->
        digest = Crypto.createHash("md5").update(File.readFileSync(filename)).digest("hex")
        browser.assert.text "body", digest


    describe "mixed", ->
      before (done)->
        brains.get "/forms/mixed", (req, res)->
          res.send """
          <html>
            <body>
              <form method="post" enctype="multipart/form-data">
                <input name="username" type="text">
                <input name="logfile" type="file">
                <button>Save</button>
              </form>
            </body>
          </html>
          """
        brains.post "/forms/mixed", (req, res)->
          data = File.readFileSync(req.files.logfile.path)
          res.send """
          <html>
            <head><title>#{req.files.logfile.name}</title></head>
            <body>#{data}</body>
          </html>
          """

        browser.visit "/forms/mixed", ->
          browser
            .fill("username", "hello")
            .attach("logfile", "#{__dirname}/data/random.txt")
            .pressButton("Save", done)

      it "should upload file", ->
        browser.assert.text "body", "Random text"
      it "should upload include name", ->
        browser.assert.text "title", "random.txt"


    describe "empty", ->
      before (done)->
        browser.visit "/forms/upload", ->
          browser
            .attach("text", "")
            .pressButton("Upload", done)

      it "should not upload any file", ->
        browser.assert.text "body", "nothing"


    describe "not set", ->
      before (done)->
        browser.visit "/forms/upload", ->
          browser.pressButton("Upload", done)

      it "should not send inputs without names", ->
        browser.assert.text "body", "nothing"


  describe "file upload with JS", ->
    before ->
      brains.get "/forms/upload-js", (req, res)->
        res.send """
        <html>
          <head>
            <title>Upload a file</title>
            <script>
              function handleFile() {
                document.title = "Upload done";
                var file = document.getElementById("my_file").files[0];
                document.getElementById("filename").innerHTML = file.name;
                document.getElementById("type").innerHTML = file.type;
                document.getElementById("size").innerHTML = file.size;
                document.getElementById("is_file").innerHTML = (file instanceof File);
              }
            </script>
          </head>
          <body>
            <form>
              <input name="my_file" id="my_file" type="file" onchange="handleFile()">
            </form>
            <div id="filename"></div>
            <div id="type"></div>
            <div id="size"></div>
            <div id="is_file"></div>
          </body>
        </html>
        """

    before (done)->
      browser.visit("/forms/upload-js")
        .then ->
          filename = "#{__dirname}/data/random.txt"
          return browser.attach("my_file", filename)
        .then(done, done)

      it "should call callback", ->
        browser.assert.text "title", "Upload done"
      it "should have filename", ->
        browser.assert.text "#filename", "random.txt"
      it "should know file type", ->
        browser.assert.text "#type", "text/plain"
      it "should know file size", ->
        browser.assert.text "#size", "12"
      it "should be of type File", ->
        browser.assert.text "#is_file", "true"


  describe "content length", ->

    describe "post form urlencoded having content", ->
      before (done)->
        brains.get "/forms/urlencoded", (req, res)->
          res.send """
          <html>
            <body>
              <form method="post">
                <input name="text" type="text">
                <input type="submit" value="submit">
              </form>
            </body>
          </html>
          """

        brains.post "/forms/urlencoded", (req, res)->
          res.send "#{req.body.text};#{req.headers["content-length"]}"

        browser.visit "/forms/urlencoded", ->
          browser
            .fill("text", "bite")
            .pressButton("submit", done)

      it "should send content-length header", ->
        [body, length] = browser.source.split(";")
        assert.equal length, "9" # text=bite
      it "should have body with content of input field", ->
        [body, length] = browser.source.split(";")
        assert.equal body, "bite"

    describe "post form urlencoded being empty", ->
      before (done)->
        brains.get "/forms/urlencoded/empty", (req, res)->
          res.send """
          <html>
            <body>
              <form method="post">
                <input type="submit" value="submit">
              </form>
            </body>
          </html>
          """

        brains.post "/forms/urlencoded/empty", (req, res)->
          res.send req.headers["content-length"]

        browser.visit "/forms/urlencoded/empty", ->
          browser.pressButton("submit", done)

      it "should send content-length header 0", ->
        assert.equal browser.source, "0"


  describe "GET form submission", ->
    before (done)->
      brains.get "/forms/get", (req, res)->
        res.send """
        <html>
          <body>
            <form method="get" action="/forms/get/echo">
              <input type="text" name="my_param" value="my_value">
              <input type="submit" value="submit">
            </form>
          </body>
        </html>
        """
      brains.get "/forms/get/echo", (req, res) ->
        res.send """
        <html>
          <body>#{req.query.my_param}</body>
        </html>
        """

      browser.visit "/forms/get", ->
        browser.pressButton("submit", done)

    it "should echo the correct query string", ->
      assert.equal browser.text("body"), "my_value"


  # DOM specifies that getAttribute returns empty string if no value, but in
  # practice it always returns `null`. However, the `name` and `value`
  # properties must return empty string.
  describe "inputs", ->
    before (done)->
      brains.get "/forms/inputs", (req, res)->
        res.send """
        <html>
          <body>
            <form>
              <input type="text">
              <textarea></textarea>
              <select></select>
              <button></button>
            </form>
          </body>
        </html>
        """
      browser.visit("/forms/inputs", done)

    it "should return empty string if name attribute not set", ->
      for tagName in ["form", "input", "textarea", "select", "button"]
        browser.assert.attribute tagName, "name", null
    it "should return empty string if value attribute not set", ->
      for tagName in ["input", "textarea", "select", "button"]
        assert.equal browser.query(tagName).getAttribute("value"), null
        assert.equal browser.query(tagName).value, ""
    it "should return empty string if id attribute not set", ->
      for tagName in ["form", "input", "textarea", "select", "button"]
        assert.equal browser.query(tagName).getAttribute("id"), null
        assert.equal browser.query(tagName).id, ""


  after ->
    browser.destroy()
