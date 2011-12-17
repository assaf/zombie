if process.version < "v0.5.0"
  Util = require("sys")
else
  Util = require("util")


class Console
  constructor: (@_silent)->

  assert: console.assert.bind(console)

  count: (name)->
    @_counters ||= {}
    @_counters[name] ||= 0
    @_counters[name]++
    @log "#{name}: #{@_counters[name]}"

  debug: ->
    @log.apply(this, arguments)

  error: ->
    @log.apply(this, arguments)

  group: ->
  groupCollapsed: ->
  groupEnd: ->

  info: ->
    @log.apply(this, arguments)

  log: ->
    formatted = ((if typeof arg == "string" then arg else Util.inspect(arg, console.showHidden, console.depth)) for arg in arguments)
    if typeof Util.format == "function"
      output = Util.format.apply(this, formatted) + "\n"
    else
      output = formatted.join(" ") + "\n"
    @_output ||= []
    @_output.push output
    unless @_silent
      process.stdout.write output

  warn: ->
    @log.apply(this, arguments)

  time: (name)->
    @_timers ||= {}
    @_timers[name] = Date.now()

  timeEnd: (name)->
    return unless @_timers
    start = @_timers[name]
    return unless start
    delete @_timers[name]
    @log "#{name}: #{Date.now() - start}ms"

  trace: ->
    stack = (new Error).stack.split("\n")
    stack[0] = "console.trace()"
    @log stack.join("\n")

  # Returns all output captured by this console.
  @prototype.__defineGetter__ "output", ->
    return (if @_output then @_output.join("\n") else "")


module.exports = Console
