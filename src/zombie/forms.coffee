# Patches to JSDOM for properly handling forms.
core = require("jsdom").dom.level3.core
path = require("path")
fs   = require("fs")
mime = require("mime")
base64 = require("base64")

# The Form
# --------
UploadedFile = (filename)->
  file = new String(path.basename(filename))
  file.mime = ()-> mime.lookup(filename)
  file.encoding = ()->
    if @mime().match(/^text/)
      null
    else
      "base64"
  file.contents = ()->
    result = fs.readFileSync(filename)
    result = base64.encode(result).replace(/(.{76})/g, "$1\r\n") if @encoding() == "base64"
    result
  return file

# Implement form.submit such that it actually submits a request to the server.
# This method takes the submitting button so we can send the button name/value.
core.HTMLFormElement.prototype.submit = (button)->
  document = @ownerDocument
  params = {}

  process = (index)=>
    if field = @elements.item(index)
      if !field.getAttribute("disabled") && name = field.getAttribute("name")
        if field.nodeName == "SELECT"
          selected = []
          for option in field.options
            selected.push(option.value) if option.selected

          if field.multiple
            value = selected
          else
            value = selected.shift()
          params[name] = value if value
        else if field.nodeName == "INPUT" && (field.type == "checkbox" || field.type == "radio")
          params[name] = field.value if field.checked
        else if field.nodeName == "INPUT" && field.type == "file"
          params[name] = new UploadedFile(field.value) if field.value
        else if field.nodeName == "TEXTAREA" || field.nodeName == "INPUT"
          params[name] = field.value if field.value

      process index + 1
    else
      params[button.name] = button.value if button && button.name
      history = document.parentWindow.history
      history._submit @getAttribute("action"), @getAttribute("method"), params, @getAttribute("enctype")
  process 0

# Implement form.reset to reset all form fields.
core.HTMLFormElement.prototype.reset = ->
  for field in @elements
    if field.nodeName == "SELECT"
      for option in field.options
        option.selected = option._defaultSelected
    else if field.nodeName == "INPUT" && field.type == "check" || field.type == "radio"
      field.checked = field._defaultChecked
    else if field.nodeName == "INPUT" || field.nodeName == "TEXTAREA"
      field.value = field._defaultValue

# Replace dispatchEvent so we can send the button along the event.
core.HTMLFormElement.prototype._dispatchSubmitEvent = (button)->
  event = @ownerDocument.createEvent("HTMLEvents")
  event.initEvent "submit", true, true
  event._button = button
  @dispatchEvent event

# Default behavior for submit events is to call the form's submit method, but we
# also pass the submitting button.
core.HTMLFormElement.prototype._eventDefaults["submit"] = (event)->
  event.target.submit event._button


# Buttons
# -------

# Default behavior for clicking on inputs.
core.HTMLInputElement.prototype._eventDefaults =
  click: (event)->
    input = event.target
    change = ->
      event = input.ownerDocument.createEvent("HTMLEvents")
      event.initEvent "change", true, true
      input.ownerDocument.dispatchEvent event
    switch input.type
      when "reset"
        if form = input.form
          form.reset()
      when "submit"
        if form = input.form
          form._dispatchSubmitEvent input
      when "checkbox"
        unless input.getAttribute("readonly")
          input.checked = !input.checked
          change()
      when "radio"
        unless input.getAttribute("readonly")
          input.checked = true
          change()

# Current INPUT behavior on click is to capture sumbit and handle it, but
# ignore all other clicks. We need those other clicks to occur, so we're going
# to dispatch them all.
core.HTMLInputElement.prototype.click = ->
  event = @ownerDocument.createEvent("HTMLEvents")
  event.initEvent "click", true, true
  @dispatchEvent event

# Default behavior for form BUTTON: submit form.
core.HTMLButtonElement.prototype._eventDefaults =
  click: (event)->
    button = event.target
    return if button.getAttribute("disabled")
    if form = button.form
      form._dispatchSubmitEvent button

# Default type for button is submit. jQuery live submit handler looks
# for the type attribute, so we've got to make sure it's there.
core.Document.prototype._elementBuilders["button"] = (doc, s)->
  button = new core.HTMLButtonElement(doc, s)
  button.type ||= "submit"
  return button
