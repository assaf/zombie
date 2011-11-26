URL = require("url")
{ raise } = require("./helpers")


# Handles the Window event loop, timers and pending requests.
class EventLoop
  constructor: (@_window)->
    @_timers = {}
    lastHandle = 0

    execute = (scope, handle, value, code)=>
      try
        @_window.browser.log "#{scope}: firing #{handle} with #{value}"
        if typeof code == "string" || code instanceof String
          @_window.run code, filename
        else
          code.call @_window
      catch error
        raise @_window.document, __filename, scope, error

    # ### window.setTimeout(fn, delay) => Number
    #
    # Implements window.setTimeout using event queue
    @_window.setTimeout = (fn, delay)=>
      timer =
        when: @_window.browser.clock + delay
        timeout: true
        fire: =>
          try
            execute "Timeout", handle, delay, fn
          finally
            delete @_timers[handle]
      handle = ++lastHandle
      @_timers[handle] = timer
      handle

    # ### window.setInterval(fn, delay) => Number
    #
    # Implements window.setInterval using event queue
    @_window.setInterval = (fn, interval)=>
      timer =
        when: @_window.browser.clock + interval
        interval: true
        fire: =>
          try
            execute "Interval", handle, interval, fn
          finally
            timer.when = @_window.browser.clock + interval
      handle = ++lastHandle
      @_timers[handle] = timer
      handle

    # ### window.clearTimeout(timeout)
    #
    # Implements window.clearTimeout using event queue
    @_window.clearTimeout = (handle)=>
      delete @_timers[handle]

    # ### window.clearInterval(interval)
    #
    # Implements window.clearInterval using event queue
    @_window.clearInterval = (handle)=>
      delete @_timers[handle]

    # Size of processing queue (number of ongoing tasks).
    @_processing = 0
    # Requests on wait that cannot be handled yet: there's no event in the
    # queue, but we anticipate one (in-progress XHR request).
    @_waiting = []
    # Called when done processing a request, and if we're done processing all
    # requests, wake up any waiting callbacks.

  # ### perform(fn)
  #
  # Run the function as part of the event queue (calls to `wait` will wait for this function to complete).  Function can
  # be anything and is called synchronous with a `done` function; when it's done processing, it lets the event loop know
  # by calling the done function.
  perform: (fn)->
    ++@_processing
    fn =>
      if --@_processing == 0
        while waiter = @_waiting.pop()
          process.nextTick waiter
    return

  # ### wait(window, terminate, callback, intervals)
  #
  # Process all events from the queue. This method returns immediately, events are processed in the background. When all
  # events are exhausted, it calls the callback with null, window; if any event fails, it calls the callback with the
  # exception.
  #
  # Events include timeout, interval and XHR onreadystatechange. DOM events are handled synchronously.
  wait: (terminate, callback, intervals)->
    process.nextTick =>
      earliest = null
      for handle, timer of @_timers
        if timer.interval && intervals == false
          continue
        if !earliest || timer.when < earliest.when
          earliest = timer
      if earliest
        intervals = false
        event = =>
          if @_window.browser.clock < earliest.when
            @_window.browser.clock = earliest.when
          earliest.fire()
      if event
        try
          event()
          done = false
          if typeof terminate == "number"
            --terminate
            if terminate <= 0
              done = true
          else if typeof terminate == "function"
            if terminate.call(@_window) == false
              done = true
          if done
            process.nextTick =>
              @_window.browser.emit "done", @_window.browser
              if callback
                callback null, @_window
          else
            @wait terminate, callback, intervals
        catch error
          @_window.browser.emit "error", error
          @wait terminate, callback, intervals
      else if @_processing > 0
        @_waiting.push =>
          @wait terminate, callback, intervals
      else
        @_window.browser.emit "done", @_window.browser
        if callback
          callback null, @_window

  dump: ->
    return [ "The time:   #{@_window.browser.clock}",
             "Timers:     #{Object.keys(@_timers).length}",
             "Processing: #{@_processing}",
             "Waiting:    #{@_waiting.length}" ]


exports.EventLoop = EventLoop
