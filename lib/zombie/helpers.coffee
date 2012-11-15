# Show deprecated message.
deprecated = (message)->
  @shown ||= {}
  unless @shown[message]
    @shown[message] = true
    process.stderr.write message


module.exports =
  deprecated: deprecated.bind(deprecated)
