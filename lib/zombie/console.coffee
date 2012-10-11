# Implements console.log, console.error, console.time, et al and emits a
# console event for each output.


{ format } = require("util")


class Console
  constructor: (@browser)->

  assert: (expression)->
    if expression
      return
    message = "Assertion failed:#{format("", Array.prototype.slice.call(arguments, 1)...)}"
    @browser.emit("console", "assert", message)
    unless @browser.silent
      process.stderr.write(message + "\n")
    throw new Error(message)

  count: (name)->
    @counters ||= {}
    @counters[name] ||= 0
    @counters[name]++
    message = "#{name}: #{@counters[name]}"
    @browser.emit("console", "count", message)
    unless @browser.silent
      process.stdout.write(message + "\n")

  group: ->
  groupCollapsed: ->
  groupEnd: ->

  time: (name)->
    @timers ||= {}
    @timers[name] = Date.now()

  timeEnd: (name)->
    return unless @timers
    start = @timers[name]
    return unless start
    delete @timers[name]
    message = "#{name}: #{Date.now() - start}ms"
    @browser.emit("console", "time", message)
    unless @browser.silent
      process.stdout.write(message + "\n")

  trace: ->
    stack = (new Error).stack.split("\n")
    stack[0] = "console.trace()"
    message = stack.join("\n")
    @browser.emit("console", "trace", message)
    unless @browser.silent
      process.stdout.write(message + "\n")


# info, log and warn all go to stdout unless browser.silent
for level in ["info", "log", "warn"]
  do (level)->
    Console.prototype[level] = ->
      message = format(arguments...)
      @browser.emit("console", level, message)
      unless @browser.silent
        process.stdout.write(message + "\n")

# debug goes to stdout but only if browser.debug
Console.prototype.debug = ->
  message = format(arguments...)
  @browser.emit("console", "debug", message)
  if @browser.debug && ! @browser.silent
    process.stdout.write(message + "\n")

# error goes to stderr unless browser.silent
Console.prototype.error = ->
  message = format(arguments...)
  @browser.emit("console", "error", message)
  unless @browser.silent
    process.stderr.write(message + "\n")


module.exports = Console
