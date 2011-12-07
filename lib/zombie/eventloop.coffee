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
        @_browser.log -> "Firing interval every #{interval}ms"
        execute "Interval", fn
      , interval)
      @_timers.push handle
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


  dispatch: (target, event)->
    @perform (done)=>
      target.dispatchEvent event
      done()

  # ### wait(window, duration, callback)
  #
  # Process all events from the queue.  This method returns immediately, events are processed in the background.  When
  # all events are exhausted, it calls the callback.
  #
  # This method will wait for any resources to load (XHR, script elements, iframes, etc).  DOM events are handled
  # synchronously, so will also wait for them.  With duration, it will wait for at least that time (in milliseconds).
  # Without duration, it will wait up to `browser.waitFor` milliseconds if there are any timeouts to run.
  wait: (window, duration, callback)->
    if duration
      # Duration given.  Wait for that duration (at least) and any processing resources afterwards.
      reduce = =>
        if @_processing > 0
          @_waiting.push reduce
        else
          @_browser.emit "done", @_browser
          process.nextTick callback
      setTimeout reduce, duration
    else
      # No duration, determine latest we're going to wait for timers.
      demise = Date.now() + @_browser.waitFor
      reduce = =>
        if @_processing > 0
          @_waiting.push reduce
        else
          # Run any timers scheduled before our give up (demise) time.
          firing = (timer._fires for timer in @_timers when timer._fires)
          if firing.length > 0
            next = Math.min(firing...)
            if next <= demise
              setTimeout reduce, next - Date.now(), 10
              return
          @_browser.emit "done", @_browser
          process.nextTick callback
      process.nextTick reduce
    return

  dump: ->
    return [ "The time:   #{new Date}",
             "Timers:     #{@_timers.length}",
             "Processing: #{@_processing}",
             "Waiting:    #{@_waiting.length}" ]


exports.EventLoop = EventLoop
