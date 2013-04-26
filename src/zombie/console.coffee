# Implements console.log, console.error, console.time, et al and emits a
# console event for each output.


{ format, inspect } = require("util")


class Console
  constructor: (@browser)->

  assert: (expression)->
    if expression
      return
    message = "Assertion failed:#{format("", Array.prototype.slice.call(arguments, 1)...)}"
    @browser.emit("console", "error", message)
    throw new Error(message)

  count: (name)->
    @counters ||= {}
    @counters[name] ||= 0
    @counters[name]++
    message = "#{name}: #{@counters[name]}"
    @browser.emit("console", "log", message)
    return

  debug: ->
    @browser.emit("console", "debug", format(arguments...))
    return

  error: ->
    @browser.emit("console", "error", format(arguments...))
    return

  group: ->
  groupCollapsed: ->
  groupEnd: ->

  dir: (object)->
    @browser.emit("console", "log", inspect(object))
    return

  info: ->
    @browser.emit("console", "info", format(arguments...))
    return

  log: ->
    @browser.emit("console", "log", format(arguments...))
    return

  time: (name)->
    @timers ||= {}
    @timers[name] = Date.now()

  timeEnd: (name)->
    if @timers
      if start = @timers[name]
        delete @timers[name]
        message = "#{name}: #{Date.now() - start}ms"
        @browser.emit("console", "log", message)
    return

  trace: ->
    stack = (new Error).stack.split("\n")
    stack[0] = "console.trace()"
    message = stack.join("\n")
    @browser.emit("console", "trace", message)
    return

  warn: ->
    @browser.emit("console", "warn", format(arguments...))
    return


module.exports = Console
