require("./helpers")
{ vows: vows, assert: assert, zombie: zombie, brains: brains } = require("vows")


brains.get "/form", (req, res)-> res.send """
  <html>
    <body>
      <form>
        <label>Name <input type="text" name="name" id="field-name"></label>
        <label for="field-email">Email</label>
        <input type="text" name="email" id="field-email"></label>
        <textarea name="likes" id="field-likes"></textarea>
        <input type="password" name="password" id="field-password">
        
        <label>Hungry <input type="checkbox" name="hungry" id="field-hungry"></label>
        <label for="field-brains">Brains?</label>
        <input type="checkbox" name="brains" id="field-brains">
        <input type="checkbox" name="dead" id="field-dead" checked>

        <label>Looks
          <select name="looks" id="field-looks">
            <option value="blood">Bloody</option>
            <option value="clean">Clean</option>
          </select>
        </label>
        <select name="state" id="field-state">
          <option value="alive">Alive</option>
          <option value="dead">Dead</option>
        </select>

        <label>Scary <input name="scary" type="radio" value="yes" id="field-scary"></label>
        <label>Not scary <input name="scary" type="radio" value="no" id="field-notscary"></label>
      </form>
    </body>
  </html>
  """

vows.describe("Forms").addBatch({
  "fill field":
    zombie.wants "http://localhost:3003/form"
      ready: (browser)->
        for field in ["email", "likes", "name", "password"]
          browser.find("#field-#{field}")[0].addEventListener "change", -> browser["#{field}Changed"] = true
        @callback null, browser
      "text input enclosed in label":
        topic: (browser)->
          browser.fill("Name", "ArmBiter")
        "should set text field": (browser)-> assert.equal browser.find("#field-name")[0].value, "ArmBiter"
        "should fire onchange event": (browser)-> assert.ok browser.nameChanged
      "email input referenced from label":
        topic: (browser)->
          browser.fill("Email", "armbiter@example.com")
        "should set email field": (browser)-> assert.equal browser.find("#field-email")[0].value, "armbiter@example.com"
        "should fire onchange event": (browser)-> assert.ok browser.emailChanged
      "textarea by field name":
        topic: (browser)->
          browser.fill("likes", "Arm Biting")
        "should set textarea": (browser)-> assert.equal browser.find("#field-likes")[0].value, "Arm Biting"
        "should fire onchange event": (browser)-> assert.ok browser.likesChanged
      "password input by selector":
        topic: (browser)->
          browser.fill(":password[name=password]", "b100d")
        "should set password": (browser)-> assert.equal browser.find("#field-password")[0].value, "b100d"
        "should fire onchange event": (browser)-> assert.ok browser.passwordChanged

  "check box":
    zombie.wants "http://localhost:3003/form"
      ready: (browser)->
        for field in ["hungry", "brains", "dead"]
          browser.find("#field-#{field}")[0].addEventListener "change", -> browser["#{field}Changed"] = true
        @callback null, browser
      "checkbox enclosed in label":
        topic: (browser)->
          browser.check "Hungry"
        "should check checkbox": (browser)-> assert.ok browser.find("#field-hungry")[0].checked
        "should fire onchange event": (browser)-> assert.ok browser.hungryChanged
      "checkbox referenced from label":
        topic: (browser)->
          browser.check "Brains?"
        "should check checkbox": (browser)-> assert.ok browser.find("#field-brains")[0].checked
        "should fire onchange event": (browser)-> assert.ok browser.brainsChanged
      "checkbox by name":
        topic: (browser)->
          browser.uncheck "dead"
        "should uncheck checkbox": (browser)-> assert.ok !browser.find("#field-dead")[0].checked
        "should fire onchange event": (browser)-> assert.ok browser.deadChanged

  "select option":
    zombie.wants "http://localhost:3003/form"
      ready: (browser)->
        for field in ["looks", "state"]
          browser.find("#field-#{field}")[0].addEventListener "change", -> browser["#{field}Changed"] = true
        @callback null, browser
      "enclosed in label using option label":
        topic: (browser)->
          browser.select "Looks", "Bloody"
        "should select option": (browser)-> assert.equal browser.find("#field-looks")[0].value, "blood"
        "should fire onchange event": (browser)-> assert.ok browser.looksChanged
      "select name using option value":
        topic: (browser)->
          browser.select "state", "dead"
        "should select option": (browser)-> assert.equal browser.find("#field-state")[0].value, "dead"
        "should fire onchange event": (browser)-> assert.ok browser.stateChanged

  "radio buttons":
    zombie.wants "http://localhost:3003/form"
      ready: (browser)->
        for field in ["scary", "notscary"]
          browser.find("#field-#{field}")[0].addEventListener "change", -> browser["#{field}Changed"] = true
        @callback null, browser
      "radio button enclosed in label":
        topic: (browser)->
          browser.choose "Scary"
        "should check radio": (browser)-> assert.ok browser.find("#field-scary")[0].checked
        "should fire onchange event": (browser)-> assert.ok browser.scaryChanged
        "radio button by value":
          topic: (browser)->
            browser.choose "no"
          "should check radio": (browser)-> assert.ok browser.find("#field-notscary")[0].checked
          "should fire onchange event": (browser)-> assert.ok browser.notscaryChanged
          "should uncheck other radio": (browser)-> assert.ok !browser.find("#field-scary")[0].checked

}).export(module);
