# Patches to JSDOM for properly handling forms.
core = require("jsdom").dom.level3.core
fs = require("fs")

# The Form
# --------

serializeFieldTypes = "email hidden number password range search text url".split(" ")
# Implement form.submit such that it actually submits a request to the server.
# This method takes the submitting button so we can send the button name/value.
core.HTMLFormElement.prototype.submit = (button)->
  document = @ownerDocument
  params = {}

  for field in @elements
    continue if field.getAttribute("disabled")
    value = null

    if field.nodeName == "SELECT"
      selected = []
      for option in field.options
        selected.push(option.value) if option.selected

      if field.multiple
        value = selected
      else
        value = selected.shift()
    else if field.nodeName == "INPUT" && (field.type == "checkbox" || field.type == "radio")
      value = field.value if field.checked
    else if field.nodeName == "INPUT" && field.type == "file"
      file = fs.readFileSync(field.value)
      file.filename = field.value
      file.mime = "text/plain"
      value = file
    else if field.nodeName == "TEXTAREA" || field.nodeName == "INPUT"
      value = field.value

    params[field.getAttribute("name")] = value if value

  params[button.name] = button.value if button && button.name
  history = document.parentWindow.history
  history._submit @getAttribute("action"), @getAttribute("method"), params, @getAttribute("enctype")

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
