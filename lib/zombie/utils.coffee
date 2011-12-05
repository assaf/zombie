
# Show deprecated message.
deprecated = (message)->
  @shown ||= {}
  unless @shown[message]
    @shown[message] = true
    console.log message


exports.deprecated = deprecated.bind(deprecated)
