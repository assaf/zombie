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
      for timer in @_timers
        global.clearTimeout timer.handle
    @_timers = []
  
  # Add event-loop features to window (mainly timers).
  apply: (window)->
    # Excecute function or evaluate string.  Scope is used for error messages, to distinguish between timeout and
    # interval.
    execute = (scope, code, notice)=>
      @_browser.log notice
      try
        if typeof code == "string" || code instanceof String
          return window.run code
        else
          return code.call window
      catch error
        raise window.document, null, __filename, scope, error
      finally
        @_next()

    # Add new timeout.  If the timeout is short enough, we ask `wait` to automatically wait for it to fire, by storing
    # the time in `timer.fires`.  We need to clear `fires` after the timer fires or when cancelled.
    window.setTimeout = (fn, delay)=>
      delay = Math.max(delay || 0, 1) # zero won't work, see below
      timer =
        # Start timer, but only schedule it during browser.wait.
        start: =>
          timer.fires = Date.now() + delay
          if @_waiting.length > 0
            timer.resume()
        # Resume timer when entering browser.wait.
        resume: ->
          if timer.fires
            timer.handle = global.setTimeout(=>
              delete timer.fires
              execute "Timeout", fn, "Firing timeout after #{delay}ms delay"
            , timer.fires - Date.now())
        # Pause timer when leaving browser.wait.
        pause: ->
          global.clearTimeout(timer.handle)
        # Cancel (clear) timer.
        stop: ->
          timer.pause()
          delete timer.fires
      timer.start()
      @_timers.push timer
      return timer

    window.setInterval = (fn, interval)=>
      timer =
        # Start timer, but only schedule it during browser.wait.
        start: =>
          timer.fires = true
          if @_waiting.length > 0
            timer.resume()
        # Resume timer when entering browser.wait.
        resume: ->
          if timer.fires
            timer.handle = global.setInterval(=>
              timer.fires = Date.now() + interval
              execute "Interval", fn, "Firing interval every #{interval}ms"
            , interval)
            timer.fires = Date.now() + interval
        # Pause timer when leaving browser.wait.
        pause: ->
          global.clearInterval(timer.handle)
        # Cancel (clear) timer.
        stop: ->
          timer.pause()
          delete timer.fires
      timer.start()
      @_timers.push timer
      return timer

    window.clearTimeout = (timer)->
      timer.stop()
    window.clearInterval = (timer)->
      timer.stop()


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
        @_next()
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

    # Handle case where we're waken up multiple times.
    done = false

    # Duration is a function, proceed until function returns false.
    waiting = =>
      return if done
      # Processing XHR/JS events, keep waiting.
      return if @_processing > 0
      try
        unless is_done && is_done(window)
          # Not done and no events, so wait for the next timer.
          timers = (timer.fires for timer in @_timers when timer.fires)
          next = Math.min.apply(Math, timers)
          if next <= done_at
            return
        @_browser.emit "done", @_browser
      catch error
        @_browser.emit "error", error
      @_waiting = (fn for fn in @_waiting when fn != waiting)
      @_pause() if @_waiting.length == 0
      done = true
      callback()

    # No one is waiting, resume firing timers.
    @_resume() if @_waiting.length == 0
    @_waiting.push waiting
    process.nextTick waiting
    return

  _next: ->
    for waiting in @_waiting
      process.nextTick waiting

  # Pause any timers from firing while we're not listening.
  _pause: ->
    for timer in @_timers
      timer.pause()

  # Resumes any timers.
  _resume: ->
    for timer in @_timers
      timer.resume()

  dump: ->
    return [ "The time:   #{new Date}",
             "Timers:     #{@_timers.length}",
             "Processing: #{@_processing}",
             "Waiting:    #{@_waiting.length}" ]


module.exports = EventLoop
