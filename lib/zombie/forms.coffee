# Patches to JSDOM for properly handling forms.
HTML = require("jsdom").dom.level3.html
Path = require("path")
File = require("fs")
Mime = require("mime")


# The Form
# --------

# Forms convert INPUT fields of type file into this object and pass it as
# parameter to resource request.
#
# The base class is a String, so the value (e.g. when passed in a GET request)
# is the base filename.  Additional properties include the MIME type (`mime`),
# the full filename (`filename`) and the `read` method that returns the file
# contents.
UploadedFile = (filename) ->
  file = new String(Path.basename(filename))
  file.filename = filename
  file.mime = Mime.lookup(filename)
  file.read = ->
    return File.readFileSync(filename)
  return file

# Implement form.submit such that it actually submits a request to the server.
# This method takes the submitting button so we can send the button name/value.
HTML.HTMLFormElement.prototype.submit = (button)->
  document = @ownerDocument
  params = []

  process = (index)=>
    if field = @elements.item(index)
      value = null

      if !field.getAttribute("disabled") && name = field.getAttribute("name")
        if field.nodeName == "SELECT"
          selected = []
          for option in field.options
            if option.selected
              selected.push(option.value)

          if field.multiple
            value = selected
          else
            value = selected.shift()
            if !value? && option = field.options[0]
              value = option.value
        else if field.nodeName == "INPUT" && (field.type == "checkbox" || field.type == "radio")
          if field.checked
            value = field.value
        else if field.nodeName == "INPUT" && field.type == "file"
          if field.value
            value = new UploadedFile(field.value)
        else if field.nodeName == "TEXTAREA" || field.nodeName == "INPUT"
          if field.value && field.type != "submit" && field.type != "image"
            value = field.value

      if value?
        params.push [name, value]
      process index + 1
    else
      if button && button.name
        params.push [button.name, button.value]
      history = document.parentWindow.history
      history._submit @getAttribute("action"), @getAttribute("method"), params, @getAttribute("enctype")
  process 0

# Implement form.reset to reset all form fields.
HTML.HTMLFormElement.prototype.reset = ->
  for field in @elements
    if field.nodeName == "SELECT"
      for option in field.options
        option.selected = option._defaultSelected
    else if field.nodeName == "INPUT" && field.type == "check" || field.type == "radio"
      field.checked = field._defaultChecked
    else if field.nodeName == "INPUT" || field.nodeName == "TEXTAREA"
      field.value = field._defaultValue

# Replace dispatchEvent so we can send the button along the event.
HTML.HTMLFormElement.prototype._dispatchSubmitEvent = (button)->
  event = @ownerDocument.createEvent("HTMLEvents")
  event.initEvent "submit", true, true
  event._button = button
  @ownerDocument.parentWindow.browser.dispatchEvent this, event

# Default behavior for submit events is to call the form's submit method, but we
# also pass the submitting button.
HTML.HTMLFormElement.prototype._eventDefaults["submit"] = (event)->
  event.target.submit event._button


# Buttons
# -------

# Default behavior for clicking on inputs.
HTML.HTMLInputElement.prototype._eventDefaults =
  click: (event)->
    input = event.target
    change = ->
      event = input.ownerDocument.createEvent("HTMLEvents")
      event.initEvent "change", true, true
      input.ownerDocument.parentWindow.browser.dispatchEvent input, event
    switch input.type
      when "reset"
        if form = input.form
          form.reset()
      when "submit", "image"
        if form = input.form
          form._dispatchSubmitEvent input
      when "checkbox"
        change()
      when "radio"
        unless input.getAttribute("readonly")
          input.checked = true
          change()

# Current INPUT behavior on click is to capture sumbit and handle it, but
# ignore all other clicks. We need those other clicks to occur, so we're going
# to dispatch them all.
HTML.HTMLInputElement.prototype.click = ->
  # First event we fire is click event
  click = =>
    event = @ownerDocument.createEvent("HTMLEvents")
    event.initEvent "click", true, true
    @ownerDocument.parentWindow.browser.dispatchEvent this, event
    return !event._preventDefault

  # If that works out, we follow with a change event
  change = =>
    event = @ownerDocument.createEvent("HTMLEvents")
    event.initEvent "change", true, true
    @ownerDocument.parentWindow.browser.dispatchEvent this, event

  switch @type
    when "checkbox"
      unless @getAttribute("readonly")
        original = @checked
        @checked = !@checked
        if click()
          change()
        else
          @checked = original
    when "radio"
      unless @getAttribute("readonly")
        if !@checked
          radios = @ownerDocument.querySelectorAll(":radio[name='#{@getAttribute("name")}']", @form)
          checked = null
          for radio in radios
            if radio.checked
              checked = radio
              radio.checked = false
          @checked = true
          if click()
            change()
          else
            for radio in radios
              radio.checked = radio == checked
        else
          click()
    else
      click()
  return

# Default behavior for form BUTTON: submit form.
HTML.HTMLButtonElement.prototype._eventDefaults =
  click: (event)->
    button = event.target
    if button.getAttribute("disabled")
      return
    else
      form = button.form
      if form
        form._dispatchSubmitEvent button

# Default type for button is submit. jQuery live submit handler looks
# for the type attribute, so we've got to make sure it's there.
HTML.Document.prototype._elementBuilders["button"] = (doc, s)->
  button = new HTML.HTMLButtonElement(doc, s)
  button.type ||= "submit"
  return button
