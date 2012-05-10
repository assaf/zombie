{ assert, brains, Browser } = require("./helpers")
File    = require("fs")
Crypto  = require("crypto")


describe "Forms", ->

  before (done)->
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
        <body>
          <div id="name">#{req.body.name}</div>
          <div id="likes">#{req.body.likes}</div>
          <div id="green">#{req.body.green}</div>
          <div id="brains">#{req.body.brains}</div>
          <div id="looks">#{req.body.looks}</div>
          <div id="hungry">#{JSON.stringify(req.body.hungry)}</div>
          <div id="state">#{req.body.state}</div>
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

    brains.ready done


  describe "fill field", ->
    browser = new Browser()

    before (done)->
      browser.visit "http://localhost:3003/forms/form", ->
        for field in ["email", "likes", "name", "password", "invalidtype", "email2"]
          do (field)->
            browser.querySelector("#field-#{field}").addEventListener "change", ->
              browser["#{field}Changed"] = true
        done()

    describe "text input enclosed in label", ->
      before ->
        browser.fill "Name", "ArmBiter"

      it "should set text field", ->
        assert.equal browser.querySelector("#field-name").value, "ArmBiter"
      it "should fire change event", ->
        assert browser.nameChanged

    describe "email input referenced from label", ->
      before ->
        browser.fill "Email", "armbiter@example.com"

      it "should set email field", ->
        assert.equal browser.querySelector("#field-email").value, "armbiter@example.com"
      it "should fire change event", ->
        assert browser.emailChanged

    describe "textarea by field name", ->
      before ->
        browser.fill "likes", "Arm Biting"

      it "should set textarea", ->
        assert.equal browser.querySelector("#field-likes").value, "Arm Biting"
      it "should fire change event", ->
        assert browser.likesChanged

    describe "password input by selector", ->
      before (done)->
        browser.fill ":password[name=password]", "b100d", done

      it "should set password", ->
        assert.equal browser.querySelector("#field-password").value, "b100d"
      it "should fire change event", ->
        assert browser.passwordChanged

    describe "input without a valid type", ->
      before ->
        browser.fill ":input[name=invalidtype]", "some value"

      it "should set value", ->
        assert.equal browser.querySelector("#field-invalidtype").value, "some value"
      it "should fire change event", ->
        assert browser.invalidtypeChanged

    describe "email2 input by node", ->
      before ->
        browser.fill browser.querySelector("#field-email2"), "headchomper@example.com"

      it "should set email2 field", ->
        assert.equal browser.querySelector("#field-email2").value, "headchomper@example.com"
      it "should fire change event", ->
        assert browser.email2Changed

    describe "disabled input can not be modified", ->
      it "should raise error", ->
        assert.throws ->
          browser.fill browser.querySelector("#disabled_input_field"), "yeahh"

    describe "readonly input can not be modified", ->
      it "should raise error", ->
        assert.throws ->
          browser.fill browser.querySelector("#readonly_input_field"), "yeahh"

    describe "should callback", ->
      before (done)->
        browser.fill browser.querySelector("#field-email3"), "headchomper@example.com", done

      it "should fire the callback", ->
        assert.equal browser.querySelector("#field-email3").value, "headchomper@example.com"


  describe "check box", ->
    browser = new Browser()

    before (done)->
      browser.visit "http://localhost:3003/forms/form", ->
        for field in ["hungry", "brains", "green"]
          do (field)->
            browser.querySelector("#field-#{field}").addEventListener "click", ->
              browser["#{field}Clicked"] = true
            browser.querySelector("#field-#{field}").addEventListener "change", ->
              browser["#{field}Changed"] = true
        done()

    describe "checkbox enclosed in label", ->
      before (done)->
        browser.check "You bet"
        browser.wait done

      it "should check checkbox", ->
        assert browser.querySelector("#field-hungry").checked
      it "should fire change event", ->
        assert browser.hungryChanged
      it "should fire clicked event", ->
        assert browser.hungryClicked

      describe "with callback", ->
        before (done)->
          browser.check "Brains?", done

        it "should callback", ->
          assert browser.querySelector("#field-brains").checked

    describe "checkbox referenced from label", ->
      before (done)->
        browser.check "Brains?"
        browser.wait done

      it "should check checkbox", ->
        assert browser.querySelector("#field-brains").checked
      it "should fire change event", ->
        assert browser.brainsChanged

      describe "uncheck with callback", ->
        browser2 = new Browser()

        before (done)->
          browser2.visit "http://localhost:3003/forms/form", ->
            browser2.check "Brains?"
            browser2.uncheck "Brains?", done

        it "should callback", ->
          assert !browser2.querySelector("#field-brains").checked

    describe "checkbox by name", ->
      before (done)->
        browser.check "green"
        browser.greenChanged = false
        browser.uncheck "green"
        browser.wait done

      it "should uncheck checkbox", ->
        assert !browser.querySelector("#field-green").checked
      it "should fire change event", ->
        assert browser.greenChanged

    describe "check callback", ->
      before (done)->
        browser.check "uncheck", done

      it "should callback", ->
        assert browser.querySelector("#field-uncheck").checked

    describe "uncheck callback", ->
      before (done)->
        browser.uncheck "check", done

      it "should callback", ->
        assert !browser.querySelector("#field-check").checked

    describe "prevent default", ->
      values = null

      before (done)->
        check_box = browser.$$("#field-prevent-check")
        values = [check_box.checked]
        check_box.addEventListener "click", (event)->
          values.push check_box.checked
          event.preventDefault()
        browser.check check_box, ->
          values.push check_box.checked
          done()

      it "should turn checkbox on then off", ->
        assert.deepEqual values, [false, true, false]


  describe "radio buttons", ->
    browser = new Browser()

    before (done)->
      browser.visit "http://localhost:3003/forms/form", ->
        for field in ["scary", "notscary"]
          do (field)->
            browser.querySelector("#field-#{field}").addEventListener "click", ->
              browser["#{field}Clicked"] = true
            browser.querySelector("#field-#{field}").addEventListener "change", ->
              browser["#{field}Changed"] = true
        done()

    describe "radio button enclosed in label", ->
      before ->
        browser.choose "Scary"

      it "should check radio", ->
        assert browser.querySelector("#field-scary").checked
      it "should fire click event", ->
        assert browser.scaryClicked
      it "should fire change event", ->
        assert browser.scaryChanged

      describe "with callback", ->
        browser = new Browser()

        before (done)->
          browser.visit "http://localhost:3003/forms/form", ->
            browser.choose "Scary", done

        it "should callback", ->
          assert browser.querySelector("#field-scary").checked

    describe "radio button by value", ->
      browser = new Browser()

      before (done)->
        browser.visit "http://localhost:3003/forms/form", ->
          browser.choose "no"
          done()

      it "should check radio", ->
        assert browser.querySelector("#field-notscary").checked
      it "should uncheck other radio", ->
        assert !browser.querySelector("#field-scary").checked

    describe "prevent default", ->
      values = null

      before (done)->
        radio = browser.$$("#field-prevent-radio")
        values = [radio.checked]
        radio.addEventListener "click", (event)->
          values.push radio.checked
          event.preventDefault()
        browser.choose radio, ->
          values.push radio.checked
          done()

      it "should turn radio on then off", ->
        assert.deepEqual values, [false, true, false]


  describe "select option", ->
    browser = new Browser()

    before (done)->
      browser.visit "http://localhost:3003/forms/form", ->
        for field in ["looks", "state", "kills"]
          do (field)->
            browser.querySelector("#field-#{field}").addEventListener "change", ->
              browser["#{field}Changed"] = true
        done()

    describe "enclosed in label using option label", ->
      before ->
        browser.select "Looks", "Bloody"

      it "should set value", ->
        assert.equal browser.querySelector("#field-looks").value, "blood"
      it "should select first option", ->
        selected = (!!option.getAttribute("selected") for option in browser.querySelector("#field-looks").options)
        assert.deepEqual selected, [true, false, false]
      it "should fire change event", ->
        assert browser.looksChanged

    describe "select name using option value", ->
      before ->
        browser.select "state", "dead"

      it "should set value", ->
        assert.equal browser.querySelector("#field-state").value, "dead"
      it "should select second option", ->
        selected = (!!option.getAttribute("selected") for option in browser.querySelector("#field-state").options)
        assert.deepEqual selected, [false, true, false]
      it "should fire change event", ->
        assert browser.stateChanged

    describe "select option value directly", ->
      before ->
        browser.selectOption browser.querySelector("#option-killed-thousands")

      it "should set value", ->
        assert.equal browser.querySelector("#field-kills").value, "Thousands"
      it "should select second option", ->
        selected = (!!option.getAttribute("selected") for option in browser.querySelector("#field-kills").options)
        assert.deepEqual selected, [false, false, true]
      it "should fire change event", ->
        assert browser.killsChanged

    describe "select callback", ->
      browser = new Browser()

      before (done)->
        browser.visit "http://localhost:3003/forms/form", ->
          browser.select "unselected_state", "dead", done

      it "should callback", ->
        assert.equal browser.querySelector("#field-unselected-state").value, "dead"

    describe "select option callback", ->
      browser = new Browser()

      before (done)->
        browser.visit "http://localhost:3003/forms/form", ->
          browser.selectOption browser.querySelector("#option-killed-thousands"), done

      it "should callback", ->
        assert.equal browser.querySelector("#field-kills").value, "Thousands"


  describe "multiple select option", ->
    browser = new Browser()

    before (done)->
      browser.visit "http://localhost:3003/forms/form", ->
        browser.querySelector("#field-hobbies").addEventListener "change", ->
          browser["hobbiesChanged"] = true
        done()

    describe "select name using option value", ->
      before ->
        browser.select "#field-hobbies", "Eat Brains"
        browser.select "#field-hobbies", "Sleep"

      it "should select first and second options", ->
        selected = (!!option.getAttribute("selected") for option in browser.querySelector("#field-hobbies").options)
        assert.deepEqual selected, [true, false, true]
      it "should fire change event", ->
        assert browser.hobbiesChanged
      it "should not fire change event if nothing changed", ->
        browser["hobbiesChanged"] = false
        browser.select "#field-hobbies", "Eat Brains"
        assert !browser.hobbiesChanged

    describe "unselect name using option value", ->
      browser = new Browser()

      before (done)->
        browser.visit "http://localhost:3003/forms/form", ->
          browser.select "#field-hobbies", "Eat Brains"
          browser.select "#field-hobbies", "Sleep"
          browser.unselect "#field-hobbies", "Sleep"
          done()

      it "should unselect items", ->
        selected = (!!option.getAttribute("selected") for option in browser.querySelector("#field-hobbies").options)
        assert.deepEqual selected, [true, false, false]

    describe "with callback", ->
      browser = new Browser()

      before (done)->
        browser.visit "http://localhost:3003/forms/form", ->
          browser.unselect "#field-hobbies", "Eat Brains"
          browser.unselect "#field-hobbies", "Sleep"
          browser.select "#field-hobbies", "Eat Brains", done

      it "should unselect callback", ->
        selected = (!!option.getAttribute("selected") for option in browser.querySelector("#field-hobbies").options)
        assert.deepEqual selected, [true, false, false]


  describe "fields not contained in a form", ->
    browser = new Browser()

    before (done)->
      browser.visit "http://localhost:3003/forms/form", done

    it "should fill text field", ->
      assert browser.fill "Hunter", "Bruce"
    it "should fill textarea", ->
      assert browser.fill "hunter_hobbies", "Trying to get home"
    it "should fill password", ->
      assert browser.fill "#hunter-password", "klaatubarada"
    it "should fill input with invalid type", ->
      assert browser.fill ":input[name=hunter_invalidtype]", "necktie?"
    it "should check checkbox", ->
      assert browser.check "Chainsaw"
    it "should choose radio", ->
      assert browser.choose "Powerglove"
    it "should choose select", ->
      assert browser.select "Type", "Evil"


  describe "reset form", ->

    describe "by calling reset", ->
      browser = new Browser()

      before (done)->
        browser.visit "http://localhost:3003/forms/form", ->
          browser.fill("Name", "ArmBiter").fill("likes", "Arm Biting").
            check("You bet").choose("Scary").select("state", "dead")
          browser.querySelector("form").reset()
          done()

      it "should reset input field to original value", ->
        assert.equal browser.querySelector("#field-name").value, ""
      it "should reset textarea to original value", ->
        assert.equal browser.querySelector("#field-likes").value, "Warm brains"
      it "should reset checkbox to original value", ->
        assert !browser.querySelector("#field-hungry").value
      it "should reset radio to original value", ->
        assert !browser.querySelector("#field-scary").checked
        assert browser.querySelector("#field-notscary").checked
      it "should reset select to original option", ->
        assert.equal browser.querySelector("#field-state").value, "alive"

    describe "with event handler", ->
      browser = new Browser()
      event = null

      before (done)->
        browser.visit "http://localhost:3003/forms/form", ->
          browser.querySelector("form :reset").addEventListener "click", ->
            event = arguments[0]
            done()
          browser.querySelector("form :reset").click()

      it "should fire click event", ->
        assert.equal event.type, "click"

    describe "with preventDefault", ->
      browser = new Browser()

      before (done)->
        browser.visit "http://localhost:3003/forms/form", ->
          browser.fill("Name", "ArmBiter")
          browser.querySelector("form :reset").addEventListener "click", (event)->
            event.preventDefault()
          browser.querySelector("form :reset").click()
          done()

      it "should not reset input field", ->
        assert.equal browser.querySelector("#field-name").value, "ArmBiter"

    describe "by clicking reset input", ->
      browser = new Browser()

      before (done)->
        browser.visit "http://localhost:3003/forms/form", ->
          browser.fill("Name", "ArmBiter")
          browser.querySelector("form :reset").click()
          done()

      it "should reset input field to original value", ->
        assert.equal browser.querySelector("#field-name").value, ""


  # Submitting form
  describe "submit form", ->

    describe "by calling submit", ->
      browser = new Browser()

      before (done)->
        browser.visit "http://localhost:3003/forms/form", ->
          console.log "Visit ..."
          browser.fill("Name", "ArmBiter").fill("likes", "Arm Biting").check("You bet").
            check("Certainly").choose("Scary").select("state", "dead").select("looks", "Choose one").
            select("#field-hobbies", "Eat Brains").select("#field-hobbies", "Sleep").check("Brains?").
            fill('#address1_city', 'Paris').fill('#address1_street', 'CDG').
            fill('#address2_city', 'Mikolaiv').fill('#address2_street', 'PGS')
          console.log "Waiting ..."
          browser.querySelector("form").submit()
          browser.wait done

      it "should open new page", ->
        assert.equal browser.location, "http://localhost:3003/forms/submit"
      it "should add location to history", ->
        assert.equal browser.window.history.length, 2
      it "should send text input values to server", ->
        assert.equal browser.text("#name"), "ArmBiter"
      it "should send textarea values to server", ->
        assert.equal browser.text("#likes"), "Arm Biting"
      it "should send radio button to server", ->
        assert.equal browser.text("#scary"), "yes"
      it "should send unknown types to server", ->
        assert.equal browser.text("#unknown"), "yes"
      it "should send checkbox with default value to server (brains)", ->
        assert.equal browser.text("#brains"), "yes"
      it "should send checkbox with default value to server (green)", ->
        assert.equal browser.text("#green"), "Super green!"
      it "should send multiple checkbox values to server", ->
        assert.equal browser.text("#hungry"), '["you bet","certainly"]'
      it "should send selected option to server", ->
        assert.equal browser.text("#state"), "dead"
      it "should send first selected option if none was chosen to server", ->
        assert.equal browser.text("#unselected_state"), "alive"
        assert.equal browser.text("#looks"), ""
      it "should send multiple selected options to server", ->
        assert.equal browser.text("#hobbies"), '["Eat Brains","Sleep"]'
      it "should send nested attributes in the order they are declared", ->
        assert.equal browser.text("#addresses"), '["CDG","Paris","PGS","Mikolaiv"]'
      it "should send empty text fields", ->
        assert.equal browser.text("#empty-text"), ""
      it "should send checked field with no value", ->
        assert.equal browser.text("#empty-checkbox"), "1"


    describe "by clicking button", ->
      browser = new Browser()

      before (done)->
        browser.visit "http://localhost:3003/forms/form", ->
          browser.fill("Name", "ArmBiter").fill("likes", "Arm Biting").pressButton "Hit Me", done

      it "should open new page", ->
        assert.equal browser.location, "http://localhost:3003/forms/submit"
      it "should add location to history", ->
        assert.equal browser.window.history.length, 2
      it "should send button value to server", ->
        assert.equal browser.text("#clicked"), "hit-me"
      it "should send input values to server", ->
        assert.equal browser.text("#name"), "ArmBiter"
        assert.equal browser.text("#likes"), "Arm Biting"
      it "should not send other button values to server", ->
        assert.equal browser.text("#image_clicked"), "undefined"

    describe "by clicking image button", ->
      browser = new Browser()

      before (done)->
        browser.visit "http://localhost:3003/forms/form", ->
          browser.fill("Name", "ArmBiter").fill("likes", "Arm Biting").pressButton "#image_submit", done

      it "should open new page", ->
        assert.equal browser.location, "http://localhost:3003/forms/submit"
      it "should add location to history", ->
        assert.equal browser.window.history.length, 2
      it "should send image value to server", ->
        assert.equal browser.text("#image_clicked"), "Image Submit"
      it "should send input values to server", ->
        assert.equal browser.text("#name"), "ArmBiter"
        assert.equal browser.text("#likes"), "Arm Biting"
      it "should not send other button values to server", ->
        assert.equal browser.text("#clicked"), "undefined"

    describe "by clicking input", ->
      browser = new Browser()

      before (done)->
        browser.visit "http://localhost:3003/forms/form", ->
          browser.fill("Name", "ArmBiter").fill("likes", "Arm Biting").pressButton "Submit", done

      it "should open new page", ->
        assert.equal browser.location, "http://localhost:3003/forms/submit"
      it "should add location to history", ->
        assert.equal browser.window.history.length, 2
      it "should send submit value to server", ->
        assert.equal browser.text("#clicked"), "Submit"
      it "should send input values to server", ->
        assert.equal browser.text("#name"), "ArmBiter"
        assert.equal browser.text("#likes"), "Arm Biting"

    describe "cancel event", ->
      browser = new Browser()

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
        browser.visit "http://localhost:3003/forms/cancel", ->
          browser.pressButton "Submit", done()

      it "should not change page", ->
        assert.equal browser.location.href, "http://localhost:3003/forms/cancel"


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
          data = File.readFileSync((text || image).path)
          if image
            digest = Crypto.createHash("md5").update(data).digest("hex")
          res.send """
          <html>
            <head><title>#{(text || image).filename}</title></head>
            <body>#{digest || data}</body>
          </html>
          """
        else
          res.send """
          <html>
            <body>nothing</body>
          </html>
          """


    describe "text", ->
      browser = new Browser()

      before (done)->
        browser.visit "http://localhost:3003/forms/upload", ->
          filename = __dirname + "/data/random.txt"
          browser.attach("text", filename).pressButton "Upload", done

      it "should upload file", ->
        assert.equal browser.text("body").trim(), "Random text"
      it "should upload include name", ->
        assert.equal browser.text("title"), "random.txt"


    describe "binary", ->
      browser = new Browser()
      filename = __dirname + "/data/zombie.jpg"

      before (done)->
        browser.visit "http://localhost:3003/forms/upload", ->
          browser.attach("image", filename).pressButton "Upload", done

      it "should upload include name", ->
        assert.equal browser.text("title"), "zombie.jpg"
      it "should upload file", ->
        digest = Crypto.createHash("md5").update(File.readFileSync(filename)).digest("hex")
        assert.equal browser.text("body").trim(), digest


    describe "mixed", ->
      browser = new Browser()

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

        browser.visit "http://localhost:3003/forms/mixed", ->
          browser
            .fill("username", "hello")
            .attach("logfile", "#{__dirname}/data/random.txt")
            .pressButton "Save", done

      it "should upload file", ->
        assert.equal browser.text("body").trim(), "Random text"
      it "should upload include name", ->
        assert.equal browser.text("title"), "random.txt"


    describe "empty", ->
      browser = new Browser()

      before (done)->
        browser.visit "http://localhost:3003/forms/upload", ->
          browser.attach "text", ""
          browser.pressButton "Upload", done

      it "should not upload any file", ->
        assert.equal browser.text("body").trim(), "nothing"


    describe "not set", ->
      browser = new Browser()

      before (done)->
        browser.visit "http://localhost:3003/forms/upload", ->
          browser.pressButton "Upload", done

      it "should not send inputs without names", ->
        assert.equal browser.text("body").trim(), "nothing"


  describe "file upload with JS", ->
    browser = new Browser()

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
      browser.visit "http://localhost:3003/forms/upload-js", ->
        filename = "#{__dirname}/data/random.txt"
        browser.attach "my_file", filename, done
          
      it "should call callback", ->
        assert.equal browser.text("title"), "Upload done"
      it "should have filename", ->
        assert.equal browser.text("#filename"), "random.txt"
      it "should know file type", ->
        assert.equal browser.text("#type"), "text/plain"
      it "should know file size", ->
        assert.equal browser.text("#size"), "12"
      it "should be of type File", ->
        assert.equal browser.text("#is_file"), "true"


  describe "content length", ->
    before ->
      brains.post "/forms/urlencoded", (req, res)->
        text = req.body.text
        res.send """
          <html>
            <head><title>bite back</title></head>
            <body>#{text}</body>
          </html>
          """

    describe "post form urlencoded having content", ->
      browser = new Browser()

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
        browser.visit "http://localhost:3003/forms/urlencoded", ->
          browser.fill("text", "bite").pressButton "submit", done

      it "should send content-length header", ->
        assert browser.lastRequest.headers["content-length"]
      it "should match expected content-length", ->
        assert.equal browser.lastRequest.headers["content-length"], "text=bite".length
      it "should have body with content of input field", ->
        assert.equal browser.text("body"), "bite"
          
    describe "post form urlencoded being empty", ->
      browser = new Browser()

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
        browser.visit "http://localhost:3003/forms/urlencoded/empty", ->
          browser.pressButton "submit", ->
            done() # 404 since there's no get for this form

      it "should send content-length header", ->
        assert browser.lastRequest.headers.hasOwnProperty("content-length")
      it "should have size of 0", ->
        assert.equal browser.lastRequest.headers["content-length"], 0

