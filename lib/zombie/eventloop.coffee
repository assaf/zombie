# An event loop.  Allows us to block waiting for asynchronous events (timers, XHR, script loading, etc).  This is
# abstracted in the API as `browser.wait`.


URL = require("url")
{ raise } = require("./helpers")


# Handles the Window event loop, timers and pending requests.
class EventLoop
  constructor: (@_browser)->

  # Reset the event loop (clearning any timers, etc) before using a new window.
  _reset: ->
    # Prevent any existing timers from firing.
    if @_timers
      for handle in @_timers
        global.clearTimeout handle
    @_timers = []
    # Size of processing queue (number of ongoing tasks).
    @_processing = 0
    # Requests on wait that cannot be handled yet: there's no event in the queue, but we anticipate one (in-progress XHR
    # request).
    @_waiting = []
  
  # Add event-loop features to window (mainly timers).
  apply: (window)->
    @_reset()

    # Excecute function or evaluate string.  Scope is used for error messages, to distinguish between timeout and
    # interval.
    execute = (scope, code)=>
      try
        if typeof code == "string" || code instanceof String
          return window.run code
        else
          return code.call window
      catch error
        raise window.document, null, __filename, scope, error

    # Add new timeout.  If the timeout is short enough, we ask `wait` to automatically wait for it to fire, by storing
    # the time in `handle._firesAt`.  We need to clear `_firesAt` after the timer fires or when cancelled.
    window.setTimeout = (fn, delay)=>
      delay ||= 1 # zero won't work, see below
      handle = global.setTimeout(=>
        delete handle._firesAt
        @_browser.log -> "Firing timeout after #{delay}ms delay"
        execute "Timeout", fn
      , delay)
      @_timers.push handle
      # Automatically wait for short timers (e.g. page load, yield)
      handle._firesAt = +new Date + delay
      return handle

    window.setInterval = (fn, interval)=>
      handle = global.setInterval(=>
        @_browser.log -> "Firing interval every #{interval}ms"
        execute "Interval", fn
      , interval)
      @_timers.push handle
      return handle

    window.clearTimeout = (handle)->
      # This one will never fire, don't wait for it.
      delete handle._firesAt
      global.clearTimeout handle
    window.clearInterval = global.clearInterval


  # ### perform(fn)
  #
  # Run the function as part of the event queue (calls to `wait` will wait for this function to complete).  Function can
  # be anything and is called synchronous with a `done` function; when it's done processing, it lets the event loop know
  # by calling the done function.
  perform: (fn)->
    ++@_processing
    fn =>
      --@_processing
      if @_processing == 0
        while waiter = @_waiting.pop()
          waiter()
    return

  # ### wait(window, duration, callback, intervals)
  #
  # Process all events from the queue.  This method returns immediately, events are processed in the background.  When
  # all events are exhausted, it calls the callback with null, window.
  #
  # This method will wait for any resources to load (XHR, script elements, iframes, etc).  DOM events are handled
  # synchronously, so will also wait for them.  It will wait at least `duration` milliseconds (default so 0), but will
  # also wait for any short timers (< 100ms delay) to fire.  These timers are used by init functions (e.g. jQuery
  # `onready`) and to yield.
  wait: (window, duration, callback)->
    setTimeout =>
      if @_processing > 0
        @_waiting.push @wait.bind(this, window, 0, callback)
      else
        # Wait for any short timers to complete.
        now = null
        for timer in @_timers
          continue unless timer._firesAt
          now ||= +new Date
          delay = now - timer._firesAt
          if delay <= 100
            @wait window, delay, callback
            return
        @_browser.emit "done", @_browser
        if callback
          callback null, window
    , duration || 0
    return

  dump: ->
    return [ "The time:   #{new Date}",
             "Timers:     #{Object.keys(@_timers).length}",
             "Processing: #{@_processing}",
             "Waiting:    #{@_waiting.length}" ]


exports.EventLoop = EventLoop
