URL = require("url")
{ raise } = require("./helpers")


# Handles the Window event loop, timers and pending requests.
class EventLoop
  constructor: (@_browser)->
    # All active timers, keyed by handle.
    @_timers = {}
    @_lastHandle = 0

    # Size of processing queue (number of ongoing tasks).
    @_processing = 0
    # Requests on wait that cannot be handled yet: there's no event in the
    # queue, but we anticipate one (in-progress XHR request).
    @_waiting = []
    # Called when done processing a request, and if we're done processing all
    # requests, wake up any waiting callbacks.
  
  # ### apply(window)
  #
  # Add event-loop features to window (mainly timers).
  apply: (window)->
    execute = (scope, handle, value, code)=>
      try
        @_browser.log "#{scope}: firing #{handle} with #{value}"
        if typeof code == "string" || code instanceof String
          return window.run code, filename
        else
          return code.call window
      catch error
        raise window.document, __filename, scope, error

    window.setTimeout = (fn, delay)=>
      handle = ++@_lastHandle
      @_timers[handle] =
        when:     @_browser.clock + delay
        timeout:  true
        fire:     =>
          if timer = @_timers[handle]
            try
              execute "Timeout", handle, delay, fn
            finally
              delete @_timers[handle]
      return handle

    window.setInterval = (fn, interval)=>
      handle = ++@_lastHandle
      @_timers[handle] =
        when:     @_browser.clock + interval
        interval: true
        fire:     =>
          if timer = @_timers[handle]
            try
              execute "Interval", handle, interval, fn
            finally
              @_timers[handle].when = @_browser.clock + interval
      return handle

    window.clearTimeout = (handle)=>
      delete @_timers[handle]

    window.clearInterval = (handle)=>
      delete @_timers[handle]


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
  wait: (window, terminate, callback, intervals)->
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
          if @_browser.clock < earliest.when
            @_browser.clock = earliest.when
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
            if terminate.call(window) == false
              done = true
          @wait window, terminate, callback, intervals
        catch error
          @_browser.emit "error", error
          @wait window, terminate, callback, intervals
      else if @_processing > 0
        @_waiting.push =>
          @wait window, terminate, callback, intervals
      else
        @_browser.emit "done", @_browser
        if callback
          callback null, window

  dump: ->
    return [ "The time:   #{@_browser.clock}",
             "Timers:     #{Object.keys(@_timers).length}",
             "Processing: #{@_processing}",
             "Waiting:    #{@_waiting.length}" ]


exports.EventLoop = EventLoop
