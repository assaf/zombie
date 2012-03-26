# Triggers an error event on the specified element.  Accepts:
# element - Element/document associated wit this error
# skip    - Filename of the caller (__filename), we use this to trim the stack trace
# scope   - Execution scope, e.g. "XHR", "Timeout"
# error   - Actual Error object
raise = ({ element, location, from, scope, error })->
  document = element.ownerDocument || element
  window = document.parentWindow
  message = if scope then "#{scope}: #{error.message}" else error.message
  location ||= document.location.href
  # Deconstruct the stack trace and strip the Zombie part of it
  # (anything leading to this file).  Add the document location at
  # the end.
  partial = []
  # "RangeError: Maximum call stack size exceeded" doesn't have a stack trace
  if error.stack
    for line in error.stack.split("\n")
      break if ~line.indexOf(from)
      partial.push line
  partial.push "    in #{location}"
  error.stack = partial.join("\n")

  event = document.createEvent("Event")
  event.initEvent "error", false, false
  event.message = error.message
  event.error = error
  window.browser.dispatchEvent window, event


# Show deprecated message.
deprecated = (message)->
  @shown ||= {}
  unless @shown[message]
    @shown[message] = true
    console.log message

translateCredentials = (credentials) ->
  switch credentials.scheme.toLowerCase()
    when "basic"
      base64 = new Buffer(credentials.user + ":" + credentials.password).toString("base64")
      "Basic #{base64}"
    when "bearer"
      "Bearer #{credentials.token}"
    when "oauth"
      "OAuth #{credentials.token}"

exports.deprecated = deprecated.bind(deprecated)
exports.raise = raise
exports.translateCredentials = translateCredentials

