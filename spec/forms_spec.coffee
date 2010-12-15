require("./helpers")
{ vows: vows, assert: assert, zombie: zombie, brains: brains } = require("vows")


brains.get "/form", (req, res)-> res.send """
  <html>
    <body>
      <form action="/submit" method="post">
        <label>Name <input type="text" name="name" id="field-name"></label>
        <label for="field-email">Email</label>
        <input type="text" name="email" id="field-email"></label>
        <textarea name="likes" id="field-likes">Warm brains</textarea>
        <input type="password" name="password" id="field-password">
        
        <label>Hungry <input type="checkbox" name="hungry" value="you bet" id="field-hungry"></label>
        <label for="field-brains">Brains?</label>
        <input type="checkbox" name="brains" id="field-brains">
        <input type="checkbox" name="green" id="field-green" checked>

        <label>Looks
          <select name="looks" id="field-looks">
            <option value="blood" label="Bloody"></option>
            <option value="clean" label="Clean"></option>
          </select>
        </label>
        <label>Scary <input name="scary" type="radio" value="yes" id="field-scary"></label>
        <label>Not scary <input name="scary" type="radio" value="no" id="field-notscary" checked></label>

        <select name="state" id="field-state">
          <option>alive</option>
          <option>dead</option>
        </select>

        <input type="reset" value="Reset">
        <input type="submit" name="button" value="Submit">

        <button name="button" value="hit-me">Hit Me</button>
      </form>
    </body>
  </html>
  """
brains.post "/submit", (req, res)-> res.send """
  <html>
    <body>
      <div id="name">#{req.body.name}</div>
      <div id="likes">#{req.body.likes}</div>
      <div id="hungry">#{req.body.hungry}</div>
      <div id="state">#{req.body.state}</div>
      <div id="scary">#{req.body.scary}</div>
      <div id="state">#{req.body.state}</div>
      <div id="clicked">#{req.body.button}</div>
    </body>
  </html>
  """

vows.describe("Forms").addBatch(
  "fill field":
    zombie.wants "http://localhost:3003/form"
      ready: (browser)->
        for field in ["email", "likes", "name", "password"]
          browser.find("#field-#{field}")[0].addEventListener "change", -> browser["#{field}Changed"] = true
        @callback null, browser
      "text input enclosed in label":
        topic: (browser)->
          browser.fill "Name", "ArmBiter"
        "should set text field": (browser)-> assert.equal browser.find("#field-name")[0].value, "ArmBiter"
        "should fire change event": (browser)-> assert.ok browser.nameChanged
      "email input referenced from label":
        topic: (browser)->
          browser.fill "Email", "armbiter@example.com"
        "should set email field": (browser)-> assert.equal browser.find("#field-email")[0].value, "armbiter@example.com"
        "should fire change event": (browser)-> assert.ok browser.emailChanged
      "textarea by field name":
        topic: (browser)->
          browser.fill "likes", "Arm Biting"
        "should set textarea": (browser)-> assert.equal browser.find("#field-likes")[0].value, "Arm Biting"
        "should fire change event": (browser)-> assert.ok browser.likesChanged
      "password input by selector":
        topic: (browser)->
          browser.fill ":password[name=password]", "b100d"
        "should set password": (browser)-> assert.equal browser.find("#field-password")[0].value, "b100d"
        "should fire change event": (browser)-> assert.ok browser.passwordChanged

  "check box":
    zombie.wants "http://localhost:3003/form"
      ready: (browser)->
        for field in ["hungry", "brains", "green"]
          browser.find("#field-#{field}")[0].addEventListener "click", -> browser["#{field}Clicked"] = true
          browser.find("#field-#{field}")[0].addEventListener "click", -> browser["#{field}Changed"] = true
        @callback null, browser
      "checkbox enclosed in label":
        topic: (browser)->
          browser.check "Hungry"
        "should check checkbox": (browser)-> assert.ok browser.find("#field-hungry")[0].checked
        "should fire click event": (browser)-> assert.ok browser.hungryClicked
        "should fire change event": (browser)-> assert.ok browser.hungryChanged
      "checkbox referenced from label":
        topic: (browser)->
          browser.check "Brains?"
        "should check checkbox": (browser)-> assert.ok browser.find("#field-brains")[0].checked
        "should fire click event": (browser)-> assert.ok browser.brainsClicked
        "should fire change event": (browser)-> assert.ok browser.brainsChanged
      "checkbox by name":
        topic: (browser)->
          browser.uncheck "green"
        "should uncheck checkbox": (browser)-> assert.ok !browser.find("#field-green")[0].checked
        "should fire click event": (browser)-> assert.ok browser.greenClicked
        "should fire change event": (browser)-> assert.ok browser.greenChanged

  "radio buttons":
    zombie.wants "http://localhost:3003/form"
      ready: (browser)->
        for field in ["scary", "notscary"]
          browser.find("#field-#{field}")[0].addEventListener "click", -> browser["#{field}Clicked"] = true
          browser.find("#field-#{field}")[0].addEventListener "click", -> browser["#{field}Changed"] = true
        @callback null, browser
      "radio button enclosed in label":
        topic: (browser)->
          browser.choose "Scary"
        "should check radio": (browser)-> assert.ok browser.find("#field-scary")[0].checked
        "should fire click event": (browser)-> assert.ok browser.scaryClicked
        "should fire change event": (browser)-> assert.ok browser.scaryChanged
        "radio button by value":
          topic: (browser)->
            browser.choose "no"
          "should check radio": (browser)-> assert.ok browser.find("#field-notscary")[0].checked
          "should uncheck other radio": (browser)-> assert.ok !browser.find("#field-scary")[0].checked
          "should fire click event": (browser)-> assert.ok browser.notscaryClicked
          "should fire change event": (browser)-> assert.ok browser.notscaryChanged

  "select option":
    zombie.wants "http://localhost:3003/form"
      ready: (browser)->
        for field in ["looks", "state"]
          browser.find("#field-#{field}")[0].addEventListener "change", -> browser["#{field}Changed"] = true
        @callback null, browser
      "enclosed in label using option label":
        topic: (browser)->
          browser.select "Looks", "Bloody"
        "should set value": (browser)-> assert.equal browser.find("#field-looks")[0].value, "blood"
        "should select first option": (browser)->
          selected = (option.selected for option in browser.find("#field-looks")[0].options)
          assert.deepEqual selected, [true, false]
        "should fire change event": (browser)-> assert.ok browser.looksChanged
      "select name using option value":
        topic: (browser)->
          browser.select "state", "dead"
        "should set value": (browser)-> assert.equal browser.find("#field-state")[0].value, "dead"
        "should select second option": (browser)->
          selected = (option.selected for option in browser.find("#field-state")[0].options)
          assert.deepEqual selected, [false, true]
        "should fire change event": (browser)-> assert.ok browser.stateChanged

  "reset form":
    "by calling reset":
      zombie.wants "http://localhost:3003/form"
        ready: (browser)->
          browser.fill("Name", "ArmBiter").fill("likes", "Arm Biting").
            check("Hungry").choose("Scary").select("state", "dead")
          browser.find("form")[0].reset()
          @callback null, browser
        "should reset input field to original value": (browser)-> assert.equal browser.find("#field-name")[0].value, ""
        "should reset textarea to original value": (browser)-> assert.equal browser.find("#field-likes")[0].value, "Warm brains"
        "should reset checkbox to original value": (browser)-> assert.ok !browser.find("#field-hungry")[0].value
        "should reset radio to original value": (browser)->
          assert.ok !browser.find("#field-scary")[0].checked
          assert.ok browser.find("#field-notscary")[0].checked
        "should reset select to original option": (browser)-> assert.equal browser.find("#field-state")[0].value, "alive"
    "with event handler":
      zombie.wants "http://localhost:3003/form"
        ready: (browser)->
          browser.find("form :reset")[0].addEventListener "click", (event)=> @callback null, event
          browser.find("form :reset")[0].click()
        "should fire click event": (event)-> assert.equal event.type, "click"
    "with preventDefault":
      zombie.wants "http://localhost:3003/form"
        ready: (browser)->
          browser.fill("Name", "ArmBiter")
          browser.find("form :reset")[0].addEventListener "click", (event)-> event.preventDefault()
          browser.find("form :reset")[0].click()
          @callback null, browser
        "should not reset input field": (browser)-> assert.equal browser.find("#field-name")[0].value, "ArmBiter"
    "by clicking reset input":
      zombie.wants "http://localhost:3003/form"
        ready: (browser)->
          browser.fill("Name", "ArmBiter")
          browser.find("form :reset")[0].click()
          @callback null, browser
        "should reset input field to original value": (browser)-> assert.equal browser.find("#field-name")[0].value, ""

  "submit form":
    "by calling submit":
      zombie.wants "http://localhost:3003/form"
        ready: (browser)->
          browser.fill("Name", "ArmBiter").fill("likes", "Arm Biting").
            check("Hungry").choose("Scary").select("state", "dead")
          browser.find("form")[0].submit()
          browser.wait @callback
        "should open new page": (browser)-> assert.equal browser.location, "http://localhost:3003/submit"
        "should add location to history": (browser)-> assert.length browser.window.history, 2
        "should send text input values to server": (browser)-> assert.equal browser.text("#name"), "ArmBiter"
        "should send textarea values to server": (browser)-> assert.equal browser.text("#likes"), "Arm Biting"
        "should send checkbox values to server": (browser)-> assert.equal browser.text("#hungry"), "you bet"
        "should send radio button to server": (browser)-> assert.equal browser.text("#scary"), "yes"
        "should send selected option to server": (browser)-> assert.equal browser.text("#state"), "dead"
    "by clicking button":
      zombie.wants "http://localhost:3003/form"
        ready: (browser)->
          browser.fill("Name", "ArmBiter").fill("likes", "Arm Biting").
            pressButton "Hit Me", @callback
        "should open new page": (browser)-> assert.equal browser.location, "http://localhost:3003/submit"
        "should add location to history": (browser)-> assert.length browser.window.history, 2
        "should send button value to server": (browser)-> assert.equal browser.text("#clicked"), "hit-me"
        "should send input values to server": (browser)->
          assert.equal browser.text("#name"), "ArmBiter"
          assert.equal browser.text("#likes"), "Arm Biting"
    "by clicking input":
      zombie.wants "http://localhost:3003/form"
        ready: (browser)->
          browser.fill("Name", "ArmBiter").fill("likes", "Arm Biting").
            pressButton "Submit", @callback
        "should open new page": (browser)-> assert.equal browser.location, "http://localhost:3003/submit"
        "should add location to history": (browser)-> assert.length browser.window.history, 2
        "should send submit value to server": (browser)-> assert.equal browser.text("#clicked"), "Submit"
        "should send input values to server": (browser)->
          assert.equal browser.text("#name"), "ArmBiter"
          assert.equal browser.text("#likes"), "Arm Biting"

).export(module);
