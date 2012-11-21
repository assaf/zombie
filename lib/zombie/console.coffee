# Implements console.log, console.error, console.time, et al and emits a
# console event for each output.


{ format } = require("util")
Hooks      = require("./hooks")


class Console
  constructor: (@browser)->

  assert: (expression)->
    if expression
      return
    message = "Assertion failed:#{format("", Array.prototype.slice.call(arguments, 1)...)}"
    @_output("error", message)
    throw new Error(message)

  count: (name)->
    @counters ||= {}
    @counters[name] ||= 0
    @counters[name]++
    message = "#{name}: #{@counters[name]}"
    @_output("count", message)
    return

  debug: ->
    @_output("debug", arguments...)
    return

  error: ->
    @_output("error", arguments...)
    return

  group: ->
  groupCollapsed: ->
  groupEnd: ->

  info: ->
    @_output("info", arguments...)
    return

  log: ->
    @_output("log", arguments...)
    return

  time: (name)->
    @timers ||= {}
    @timers[name] = Date.now()

  timeEnd: (name)->
    if @timers
      if start = @timers[name]
        delete @timers[name]
        message = "#{name}: #{Date.now() - start}ms"
        @_output("time", message)
    return

  trace: ->
    stack = (new Error).stack.split("\n")
    stack[0] = "console.trace()"
    message = stack.join("\n")
    @_output("trace", message)
    return

  warn: ->
    @_output("warn", arguments...)
    return


  # info, log and warn all go to stdout unless browser.silent
  # debug goes to stdout only if debug flag is true
  # error goes to stderr unless browser.silent
  _output: (level, args...)->
    message = format(args...)
    @browser.emit("console", "level", message)
    unless @browser.silent
      switch level
        when "error"
          process.stderr.write(message + "\n")
        when "debug"
          if @browser.debug
            process.stdout.write(message + "\n")
        else
          process.stdout.write(message + "\n")
    return


module.exports = Console
