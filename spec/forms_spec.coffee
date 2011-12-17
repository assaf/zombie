{ Vows, assert, brains, Browser } = require("./helpers")
File = require("fs")
Crypto = require("crypto")


Vows.describe("Forms").addBatch(

  "standard":
    topic: ->
      brains.get "/forms/form", (req, res)->
        res.send """
        <html>
          <body>
            <form action="/forms/submit" method="post">
              <label>Name <input type="text" name="name" id="field-name"></label>
              <label for="field-email">Email</label>
              <input type="text" name="email" id="field-email"></label>
              <textarea name="likes" id="field-likes">Warm brains</textarea>
              <input type="password" name="password" id="field-password">
              <input type="badtype" name="invalidtype" id="field-invalidtype" />
              <input type="text" name="email2" id="field-email2" />
              <input type="text" name="email3" id="field-email3" />

              <label>Hungry</label>
              <label>You bet<input type="checkbox" name="hungry[]" value="you bet" id="field-hungry"></label>
              <label>Certainly<input type="checkbox" name="hungry[]" value="certainly" id="field-hungry-certainly"></label>

              <label for="field-brains">Brains?</label>
              <input type="checkbox" name="brains" value="yes" id="field-brains">
              <input type="checkbox" name="green" id="field-green" value="Super green!" checked="checked">
              
              <input type="checkbox" name="check" id="field-check" value="Huh?" checked="checked">
              <input type="checkbox" name="uncheck" id="field-uncheck" value="Yeah!">

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
            </form>
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
            <div id="unselected_state">#{req.body.unselected_state}</div>
            <div id="hobbies">#{JSON.stringify(req.body.hobbies)}</div>
            <div id="addresses">#{JSON.stringify(req.body.addresses)}</div>
            <div id="unknown">#{req.body.unknown}</div>
            <div id="clicked">#{req.body.button}</div>
            <div id="image_clicked">#{req.body.image}</div>
          </body>
        </html>
        """

    "fill field":
      Browser.wants "http://localhost:3003/forms/form"
        topic: (browser)->
          for field in ["email", "likes", "name", "password", "invalidtype", "email2"]
            do (field)->
              browser.querySelector("#field-#{field}").addEventListener "change", ->
                browser["#{field}Changed"] = true
          @callback null, browser

        "text input enclosed in label":
          topic: (browser)->
            browser.fill "Name", "ArmBiter"
          "should set text field": (browser)->
            assert.equal browser.querySelector("#field-name").value, "ArmBiter"
          "should fire change event": (browser)->
            assert.ok browser.nameChanged

        "email input referenced from label":
          topic: (browser)->
            browser.fill "Email", "armbiter@example.com"
          "should set email field": (browser)->
            assert.equal browser.querySelector("#field-email").value, "armbiter@example.com"
          "should fire change event": (browser)->
            assert.ok browser.emailChanged

        "textarea by field name":
          topic: (browser)->
            browser.fill "likes", "Arm Biting"
          "should set textarea": (browser)->
            assert.equal browser.querySelector("#field-likes").value, "Arm Biting"
          "should fire change event": (browser)->
            assert.ok browser.likesChanged

        "password input by selector":
          topic: (browser)->
            browser.fill ":password[name=password]", "b100d"
          "should set password": (browser)->
            assert.equal browser.querySelector("#field-password").value, "b100d"
          "should fire change event": (browser)->
            assert.ok browser.passwordChanged

        "input without a valid type":
          topic: (browser)->
            browser.fill ":input[name=invalidtype]", "some value"
          "should set value": (browser)->
            assert.equal browser.querySelector("#field-invalidtype").value, "some value"
          "should fire change event": (browser)->
            assert.ok browser.invalidtypeChanged

        "email2 input by node":
          topic: (browser)->
            browser.fill browser.querySelector("#field-email2"), "headchomper@example.com"
          "should set email2 field": (browser)->
            assert.equal browser.querySelector("#field-email2").value, "headchomper@example.com"
          "should fire change event": (browser)->
            assert.ok browser.email2Changed

        "should callback":
          topic: (browser)->
            browser.fill browser.querySelector("#field-email3"), "headchomper@example.com", @callback
          "should fire the callback": (_, browser)->
            assert.equal browser.querySelector("#field-email3").value, "headchomper@example.com"


    "check box":
      Browser.wants "http://localhost:3003/forms/form"
        topic: (browser)->
          for field in ["hungry", "brains", "green"]
            do (field)->
              browser.querySelector("#field-#{field}").addEventListener "click", ->
                browser["#{field}Clicked"] = true
              browser.querySelector("#field-#{field}").addEventListener "change", ->
                browser["#{field}Changed"] = true
          @callback null, browser

        "checkbox enclosed in label":
          topic: (browser)->
            browser.check "You bet"
            browser.wait @callback
          "should check checkbox": (browser)->
            assert.ok browser.querySelector("#field-hungry").checked
          "should fire change event": (browser)->
            assert.ok browser.hungryChanged
          "should fire clicked event": (browser)->
            assert.ok browser.hungryClicked
          "with callback":
            Browser.wants "http://localhost:3003/forms/form"
              topic: (browser)->
                browser.check "Brains?", @callback
              "should callback": (_, browser)->
                assert.ok browser.querySelector("#field-brains").checked

        "checkbox referenced from label":
          topic: (browser)->
            browser.check "Brains?"
            browser.wait @callback
          "should check checkbox": (browser)->
            assert.ok browser.querySelector("#field-brains").checked
          "should fire change event": (browser)->
            assert.ok browser.brainsChanged
          "uncheck with callback":
            Browser.wants "http://localhost:3003/forms/form"
              topic: (browser)->
                browser.check "Brains?"
                browser.uncheck "Brains?", @callback
              "should callback": (_, browser)->
                assert.ok !browser.querySelector("#field-brains").checked

        "checkbox by name":
          topic: (browser)->
            browser.check "green"
            browser["greenChanged"] = false
            browser.uncheck "green"
            browser.wait @callback
          "should uncheck checkbox": (browser)->
            assert.ok !browser.querySelector("#field-green").checked
          "should fire change event": (browser)->
            assert.ok browser.greenChanged
        "check callback":
          topic: (browser)->
            browser.check "uncheck", @callback
          "should callback": (_, browser)->
            assert.ok browser.querySelector("#field-uncheck").checked
        "uncheck callback":
          topic: (browser)->
            browser.uncheck "check", @callback
          "should callback": (_, browser)->
            assert.ok !browser.querySelector("#field-check").checked

          
    "radio buttons":
      Browser.wants "http://localhost:3003/forms/form"
        topic: (browser)->
          for field in ["scary", "notscary"]
            do (field)->
              browser.querySelector("#field-#{field}").addEventListener "click", ->
                browser["#{field}Clicked"] = true
              browser.querySelector("#field-#{field}").addEventListener "change", ->
                browser["#{field}Changed"] = true
          @callback null, browser

        "radio button enclosed in label":
          topic: (browser)->
            browser.choose "Scary"
          "should check radio": (browser)->
            assert.ok browser.querySelector("#field-scary").checked
          "should fire click event": (browser)->
            assert.ok browser.scaryClicked
          "should fire change event": (browser)->
            assert.ok browser.scaryChanged
          "with callback":
            Browser.wants "http://localhost:3003/forms/form"
              topic: (browser)->
                browser.choose "Scary", @callback
              "should callback": (_, browser)->
                assert.ok browser.querySelector("#field-scary").checked

        "radio button by value":
          Browser.wants "http://localhost:3003/forms/form"
            topic: (browser)->
              browser.choose "no"
            "should check radio": (browser)->
              assert.ok browser.querySelector("#field-notscary").checked
            "should uncheck other radio": (browser)->
              assert.ok !browser.querySelector("#field-scary").checked


    "select option":
      Browser.wants "http://localhost:3003/forms/form"
        topic: (browser)->
          for field in ["looks", "state", "kills"]
            do (field)->
              browser.querySelector("#field-#{field}").addEventListener "change", ->
                browser["#{field}Changed"] = true
          @callback null, browser

        "enclosed in label using option label":
          topic: (browser)->
            browser.select "Looks", "Bloody"
          "should set value": (browser)->
            assert.equal browser.querySelector("#field-looks").value, "blood"
          "should select first option": (browser)->
            selected = (!!option.getAttribute("selected") for option in browser.querySelector("#field-looks").options)
            assert.deepEqual selected, [true, false, false]
          "should fire change event": (browser)->
            assert.ok browser.looksChanged

        "select name using option value":
          topic: (browser)->
            browser.select "state", "dead"
          "should set value": (browser)->
            assert.equal browser.querySelector("#field-state").value, "dead"
          "should select second option": (browser)->
            selected = (!!option.getAttribute("selected") for option in browser.querySelector("#field-state").options)
            assert.deepEqual selected, [false, true, false]
          "should fire change event": (browser)->
            assert.ok browser.stateChanged

        "select option value directly":
          topic: (browser)->
            browser.selectOption browser.querySelector("#option-killed-thousands")
          "should set value": (browser)->
            assert.equal browser.querySelector("#field-kills").value, "Thousands"
          "should select second option": (browser)->
            selected = (!!option.getAttribute("selected") for option in browser.querySelector("#field-kills").options)
            assert.deepEqual selected, [false, false, true]
          "should fire change event": (browser)->
            assert.ok browser.killsChanged

        "select callback":
          Browser.wants "http://localhost:3003/forms/form"
            topic: (browser)->
              browser.select "unselected_state", "dead", @callback
            "should callback": (_, browser)->
              assert.equal browser.querySelector("#field-unselected-state").value, "dead"

        "select option callback":
          Browser.wants "http://localhost:3003/forms/form"
            topic: (browser)->
              browser.selectOption browser.querySelector("#option-killed-thousands"), @callback
            "should callback": (_, browser)->
              assert.equal browser.querySelector("#field-kills").value, "Thousands"


    "multiple select option":
      Browser.wants "http://localhost:3003/forms/form"
        topic: (browser)->
          browser.querySelector("#field-hobbies").addEventListener "change", ->
            browser["hobbiesChanged"] = true
          @callback null, browser

        "select name using option value":
          topic: (browser)->
            browser.select "#field-hobbies", "Eat Brains"
            browser.select "#field-hobbies", "Sleep"
          "should select first and second options": (browser)->
            selected = (!!option.getAttribute("selected") for option in browser.querySelector("#field-hobbies").options)
            assert.deepEqual selected, [true, false, true]
          "should fire change event": (browser)->
            assert.ok browser.hobbiesChanged
          "should not fire change event if nothing changed": (browser)->
            browser["hobbiesChanged"] = false
            browser.select "#field-hobbies", "Eat Brains"
            assert.ok !browser.hobbiesChanged

        "unselect name using option value":
          Browser.wants "http://localhost:3003/forms/form"
            topic: (browser)->
              browser.select "#field-hobbies", "Eat Brains"
              browser.select "#field-hobbies", "Sleep"
              browser.unselect "#field-hobbies", "Sleep"
            "should unselect items": (browser)->
              selected = (!!option.getAttribute("selected") for option in browser.querySelector("#field-hobbies").options)
              assert.deepEqual selected, [true, false, false]

        "with callback":
          Browser.wants "http://localhost:3003/forms/form"
            topic: (browser)->
              browser.unselect "#field-hobbies", "Eat Brains"
              browser.unselect "#field-hobbies", "Sleep"
              browser.select "#field-hobbies", "Eat Brains", @callback
            "should unselect callback": (_, browser)->
              selected = (!!option.getAttribute("selected") for option in browser.querySelector("#field-hobbies").options)
              assert.deepEqual selected, [true, false, false]


    "reset form":
      "by calling reset":
        Browser.wants "http://localhost:3003/forms/form"
          topic: (browser)->
            browser.fill("Name", "ArmBiter").fill("likes", "Arm Biting").
              check("You bet").choose("Scary").select("state", "dead")
            browser.querySelector("form").reset()
            @callback null, browser
          "should reset input field to original value": (browser)->
            assert.equal browser.querySelector("#field-name").value, ""
          "should reset textarea to original value": (browser)->
            assert.equal browser.querySelector("#field-likes").value, "Warm brains"
          "should reset checkbox to original value": (browser)->
            assert.ok !browser.querySelector("#field-hungry").value
          "should reset radio to original value": (browser)->
            assert.ok !browser.querySelector("#field-scary").checked
            assert.ok browser.querySelector("#field-notscary").checked
          "should reset select to original option": (browser)->
            assert.equal browser.querySelector("#field-state").value, "alive"

      "with event handler":
        Browser.wants "http://localhost:3003/forms/form"
          topic: (browser)->
            browser.querySelector("form :reset").addEventListener "click", (event)=>
              @callback null, event
            browser.querySelector("form :reset").click()
          "should fire click event": (event)->
            assert.equal event.type, "click"

      "with preventDefault":
        Browser.wants "http://localhost:3003/forms/form"
          topic: (browser)->
            browser.fill("Name", "ArmBiter")
            browser.querySelector("form :reset").addEventListener "click", (event)->
              event.preventDefault()
            browser.querySelector("form :reset").click()
            @callback null, browser
          "should not reset input field": (browser)->
            assert.equal browser.querySelector("#field-name").value, "ArmBiter"

      "by clicking reset input":
        Browser.wants "http://localhost:3003/forms/form"
          topic: (browser)->
            browser.fill("Name", "ArmBiter")
            browser.querySelector("form :reset").click()
            @callback null, browser
          "should reset input field to original value": (browser)->
            assert.equal browser.querySelector("#field-name").value, ""


    # Submitting form
    "submit form":
      "by calling submit":
        Browser.wants "http://localhost:3003/forms/form"
          topic: (browser)->
            browser.fill("Name", "ArmBiter").fill("likes", "Arm Biting").check("You bet").
              check("Certainly").choose("Scary").select("state", "dead").select("looks", "Choose one").
              select("#field-hobbies", "Eat Brains").select("#field-hobbies", "Sleep").check("Brains?").
              fill('#address1_city', 'Paris').fill('#address1_street', 'CDG').
              fill('#address2_city', 'Mikolaiv').fill('#address2_street', 'PGS')
            browser.querySelector("form").submit()
            browser.wait @callback

          "should open new page": (browser)->
            assert.equal browser.location, "http://localhost:3003/forms/submit"
          "should add location to history": (browser)->
            assert.lengthOf browser.window.history, 2
          "should send text input values to server": (browser)->
            assert.equal browser.text("#name"), "ArmBiter"
          "should send textarea values to server": (browser)->
            assert.equal browser.text("#likes"), "Arm Biting"
          "should send radio button to server": (browser)->
            assert.equal browser.text("#scary"), "yes"
          "should send unknown types to server": (browser)->
            assert.equal browser.text("#unknown"), "yes"
          "should send checkbox with default value to server": (browser)->
            assert.equal browser.text("#brains"), "yes"
          "should send checkbox with default value to server": (browser)->
            assert.equal browser.text("#green"), "Super green!"
          "should send multiple checkbox values to server": (browser)->
            assert.equal browser.text("#hungry"), '["you bet","certainly"]'
          "should send selected option to server": (browser)->
            assert.equal browser.text("#state"), "dead"
          "should send first selected option if none was chosen to server": (browser)->
            assert.equal browser.text("#unselected_state"), "alive"
            assert.equal browser.text("#looks"), ""
          "should send multiple selected options to server": (browser)->
            assert.equal browser.text("#hobbies"), '["Eat Brains","Sleep"]'
          "should send nested attributes in the order they are declared": (browser) ->
            assert.equal browser.text("#addresses"), '["CDG","Paris","PGS","Mikolaiv"]'

      "by clicking button":
        Browser.wants "http://localhost:3003/forms/form"
          topic: (browser)->
            browser.fill("Name", "ArmBiter").fill("likes", "Arm Biting").pressButton "Hit Me", @callback
          "should open new page": (browser)->
            assert.equal browser.location, "http://localhost:3003/forms/submit"
          "should add location to history": (browser)->
            assert.lengthOf browser.window.history, 2
          "should send button value to server": (browser)->
            assert.equal browser.text("#clicked"), "hit-me"
          "should send input values to server": (browser)->
            assert.equal browser.text("#name"), "ArmBiter"
            assert.equal browser.text("#likes"), "Arm Biting"
          "should not send other button values to server": (browser)->
            assert.equal browser.text("#image_clicked"), "undefined"

      "by clicking image button":
        Browser.wants "http://localhost:3003/forms/form"
          topic: (browser)->
            browser.fill("Name", "ArmBiter").fill("likes", "Arm Biting").pressButton "#image_submit", @callback
          "should open new page": (browser)->
            assert.equal browser.location, "http://localhost:3003/forms/submit"
          "should add location to history": (browser)->
            assert.lengthOf browser.window.history, 2
          "should send image value to server": (browser)->
            assert.equal browser.text("#image_clicked"), "Image Submit"
          "should send input values to server": (browser)->
            assert.equal browser.text("#name"), "ArmBiter"
            assert.equal browser.text("#likes"), "Arm Biting"
          "should not send other button values to server": (browser)->
            assert.equal browser.text("#clicked"), "undefined"

      "by clicking input":
        Browser.wants "http://localhost:3003/forms/form"
          topic: (browser)->
            browser.fill("Name", "ArmBiter").fill("likes", "Arm Biting").pressButton "Submit", @callback
          "should open new page": (browser)->
            assert.equal browser.location, "http://localhost:3003/forms/submit"
          "should add location to history": (browser)->
            assert.lengthOf browser.window.history, 2
          "should send submit value to server": (browser)->
            assert.equal browser.text("#clicked"), "Submit"
          "should send input values to server": (browser)->
            assert.equal browser.text("#name"), "ArmBiter"
            assert.equal browser.text("#likes"), "Arm Biting"


  # File upload
  "file upload":
    topic: ->
      brains.get "/forms/upload", (req, res)->
        res.send """
        <html>
          <body>
            <form method="post" enctype="multipart/form-data">
              <input name="text" type="file">
              <input name="image" type="file">
              <button>Upload</button>
            </form>

            <form>
              <input name="get_file" type="file">
              <input type="submit" value="Get Upload">
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

    "text":
      Browser.wants "http://localhost:3003/forms/upload"
        topic: (browser)->
          filename = __dirname + "/data/random.txt"
          browser.attach("text", filename).pressButton "Upload", @callback
        "should upload file": (browser)->
          assert.equal browser.text("body").trim(), "Random text"
        "should upload include name": (browser)->
          assert.equal browser.text("title"), "random.txt"

    "binary":
      Browser.wants "http://localhost:3003/forms/upload"
        topic: (browser)->
          @filename = __dirname + "/data/zombie.jpg"
          browser.attach("image", @filename).pressButton "Upload", @callback
        "should upload include name": (browser)->
          assert.equal browser.text("title"), "zombie.jpg"
        "should upload file": (browser)->
          digest = Crypto.createHash("md5").update(File.readFileSync(@filename)).digest("hex")
          assert.equal browser.text("body").trim(), digest

    "empty":
      Browser.wants "http://localhost:3003/forms/upload"
        topic: (browser)->
          browser.attach "text", ""
          browser.pressButton "Upload", @callback
        "should not upload any file": (browser)->
          assert.equal browser.text("body").trim(), "nothing"

    "not set":
      Browser.wants "http://localhost:3003/forms/upload"
        topic: (browser)->
          browser.pressButton "Upload", @callback
        "should not send inputs without names": (browser)->
          assert.equal browser.text("body").trim(), "nothing"

    "get":
      Browser.wants "http://localhost:3003/forms/upload"
        topic: (browser)->
          filename = __dirname + "/data/random.txt"
          browser.attach("get_file", filename).pressButton "Get Upload", @callback
        "should send just the file basename": (browser)->
          assert.equal browser.location.search, "?get_file=random.txt"
          
          
  "content length":
    topic: ->
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
        text = req.body.text
        res.send """
          <html>
            <head><title>bite back</title></head>
            <body>#{text}</body>
          </html>
          """

    "post form urlencoded having content":
      Browser.wants "http://localhost:3003/forms/urlencoded"
        topic: (browser)->
          browser.fill("text", "bite").pressButton "submit", @callback
        "should send content-length header": (browser) ->
          assert.include browser.lastRequest.headers, "content-length"
        "should match expected content-length": (browser) ->
          assert.equal browser.lastRequest.headers["content-length"], "text=bite".length
        "should have body with content of input field": (browser) ->
          assert.equal browser.text("body"), "bite"
          
    "post form urlencoded being empty":
      Browser.wants "http://localhost:3003/forms/urlencoded"
        topic: (browser)->
          browser.pressButton "submit", @callback
        "should send content-length header": (browser) ->
          assert.include browser.lastRequest.headers, "content-length"
        "should have size of 0": (browser) ->
          assert.equal browser.lastRequest.headers["content-length"], 0


).export(module)
