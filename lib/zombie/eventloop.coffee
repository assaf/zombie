# An event loop.  Allows us to block waiting for asynchronous events (timers, XHR, script loading, etc).  This is
# abstracted in the API as `browser.wait`.


URL = require("url")
{ raise } = require("./helpers")


# Handles the Window event loop, timers and pending requests.
class EventLoop
  constructor: (@_browser)->
    # Size of processing queue (number of ongoing tasks).
    @_processing = 0
    # Requests on wait that cannot be handled yet: there's no event in the queue, but we anticipate one (in-progress XHR
    # request).
    @_waiting = []

  # Reset the event loop (clearning any timers, etc) before using a new window.
  reset: ->
    # Prevent any existing timers from firing.
    if @_timers
      for handle in @_timers
        global.clearTimeout handle
    @_timers = []
  
  # Add event-loop features to window (mainly timers).
  apply: (window)->
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
      finally
        while waiter = @_waiting.pop()
          process.nextTick waiter

    # Add new timeout.  If the timeout is short enough, we ask `wait` to automatically wait for it to fire, by storing
    # the time in `handle._fires`.  We need to clear `_fires` after the timer fires or when cancelled.
    window.setTimeout = (fn, delay)=>
      delay = Math.max(delay || 0, 1) # zero won't work, see below
      handle = global.setTimeout(=>
        delete handle._fires
        @_browser.log -> "Firing timeout after #{delay}ms delay"
        execute "Timeout", fn
      , delay)
      @_timers.push handle
      # Automatically wait for short timers (e.g. page load, yield)
      handle._fires = Date.now() + delay
      return handle

    window.setInterval = (fn, interval)=>
      handle = global.setInterval(=>
        handle._fires = Date.now() + interval
        @_browser.log -> "Firing interval every #{interval}ms"
        execute "Interval", fn
      , interval)
      @_timers.push handle
      handle._fires = Date.now() + interval
      return handle

    window.clearTimeout = (handle)->
      # This one will never fire, don't wait for it.
      delete handle._fires
      global.clearTimeout handle
    window.clearInterval = (handle)->
      delete handle._fires
      global.clearInterval handle


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
          process.nextTick waiter
    return

  # Dispatch event asynchronously, wait for it to complete.
  dispatch: (target, event)->
    @perform (done)=>
      target.dispatchEvent event
      done()

  # Process all events from the queue.  This method returns immediately, events
  # are processed in the background.  When all events are exhausted, it calls
  # the callback.
  #
  # This method will wait for any resources to load (XHR, script elements,
  # iframes, etc).  DOM events are handled synchronously, so will also wait for
  # them.
  #
  # Duration is either how long to wait, or a function evaluated against the
  # window that returns true when done.  The default duration is
  # `browser.waitFor`.
  wait: (window, duration, callback)->
    if typeof duration == "function"
      is_done = duration
      done_at = Date.now() + 10000 # don't block forever
    else
      unless duration && duration != 0
        duration = @_browser.waitFor
      done_at = Date.now() + (duration || 0)

    # Duration is a function, proceed until function returns false.
    reduce = =>
      if @_processing > 0
        @_waiting.push reduce
      else
        try
          unless is_done && is_done(window)
            # Not done and no events, so wait for the next timer.
            timers = (timer._fires for timer in @_timers when timer._fires)
            next = Math.min.apply(Math, timers)
            if next <= done_at
              @_waiting.push reduce
              return
          @_browser.emit "done", @_browser
          process.nextTick callback
        catch error
          @_browser.emit "error", error
          callback error
    process.nextTick reduce
    return


  dump: ->
    return [ "The time:   #{new Date}",
             "Timers:     #{@_timers.length}",
             "Processing: #{@_processing}",
             "Waiting:    #{@_waiting.length}" ]


module.exports = EventLoop
