core = require("jsdom").dom.level3.core


serializeFieldTypes = "email number password range search text url".split(" ")
core.HTMLFormElement.prototype.submit = -> @_submit()
# Implement form.submit such that it actually submits a request to the server.
# This method takes the submitting button so we can send the button name/value.
core.HTMLFormElement.prototype._submit = (button)->
  document = @ownerDocument
  params = {}
  for field in @elements
    continue if field.getAttribute("disabled")
    if field.nodeName == "SELECT" || field.nodeName == "TEXTAREA" || (field.nodeName == "INPUT" && serializeFieldTypes.indexOf(field.type) >= 0)
      params[field.getAttribute("name")] = field.value
    else if field.nodeName == "INPUT" && (field.type == "checkbox" || field.type == "radio")
      params[field.getAttribute("name")] = field.value if field.checked
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
core.HTMLFormElement.prototype._eventDefault = (event)->
  @_submit event._button if event.type == "submit"

# Default behavior for clicking on reset/submit buttons.
core.HTMLInputElement.prototype._eventDefault = (event)->
  return if @getAttribute("disabled")
  if event.type == "click" && form = @form
    switch @type
      when "reset" then form.reset()
      when "submit" then form._dispatchSubmitEvent this

# Current INPUT behavior on click is to capture sumbit and handle it, but
# ignore all other clicks. We need those other clicks to occur, so we're going
# to dispatch them all.
core.HTMLInputElement.prototype.click = ->
  if @type == "checkbox" || @type == "radio"
    @checked = !@checked
  # Instead of handling event directly we bubble it and let the default behavior kick in.
  event = @ownerDocument.createEvent("HTMLEvents")
  event.initEvent "click", true, true
  @dispatchEvent event

# Default behavior for form BUTTON: submit form.
core.HTMLButtonElement.prototype._eventDefault = (event)->
  return if @getAttribute("disabled")
  if event.type == "click" && form = @form
    form._dispatchSubmitEvent this
