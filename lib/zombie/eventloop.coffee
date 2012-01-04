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
        raise element: window.document, from: __filename, scope: scope, error: error
      finally
        @_next()

    # Add new timeout.  If the timeout is short enough, we ask `wait` to automatically wait for it to fire, by storing
    # the time in `timer.next`.  We need to clear `next` after the timer fires or when cancelled.
    window.setTimeout = (fn, delay)=>
      delay = Math.max(delay || 0, 1) # zero won't work, see below
      timer =
        # Start timer, but only schedule it during browser.wait.
        start: =>
          timer.next = Date.now() + delay
          if @_waiting.length > 0
            timer.resume()
        # Resume timer when entering browser.wait.
        resume: ->
          if timer.next
            timer.next = Date.now() + delay
            timer.handle = global.setTimeout(=>
              delete timer.next
              execute "Timeout", fn, "Firing timeout after #{delay}ms delay"
            , timer.next - Date.now())
        # Pause timer when leaving browser.wait.
        pause: ->
          delay = timer.next - Date.now()
          global.clearTimeout(timer.handle)
        # Cancel (clear) timer.
        stop: ->
          timer.pause()
          delete timer.next
      timer.start()
      @_timers.push timer
      return timer

    window.setInterval = (fn, interval)=>
      timer =
        # Start timer, but only schedule it during browser.wait.
        start: =>
          timer.next = true
          if @_waiting.length > 0
            timer.resume()
        # Resume timer when entering browser.wait.
        resume: ->
          if timer.next
            timer.handle = global.setInterval(=>
              timer.next = Date.now() + interval
              execute "Interval", fn, "Firing interval every #{interval}ms"
            , interval)
            timer.next = Date.now() + interval
        # Pause timer when leaving browser.wait.
        pause: ->
          global.clearInterval(timer.handle)
        # Cancel (clear) timer.
        stop: ->
          timer.pause()
          delete timer.next
      timer.start()
      @_timers.push timer
      return timer

    window.clearTimeout = (timer)->
      if timer && timer.stop && timer.next
        timer.stop()
    window.clearInterval = (timer)->
      if timer && timer.stop && timer.next
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
      done_at = Infinity
    else
      unless duration && duration != 0
        duration = @_browser.waitFor
      done_at = Date.now() + (duration || 0)

    # Called once at the end of the loop. Also, set to null when done, since
    # waiting may be called multiple times.
    done = (error)=>
      # Mark as done so we don't run it again.
      done = null
      # Remove from waiting list, pause timers if last waiting.
      @_waiting = (fn for fn in @_waiting when fn != waiting)
      @_pause() if @_waiting.length == 0
      process.nextTick ->
        callback error, window
      if terminate
        clearTimeout(terminate)

    # don't block forever
    terminate = setTimeout(done, 5000)

    # Duration is a function, proceed until function returns false.
    waiting = =>
      # May be called multiple times from nextTick
      return unless done
      # Processing XHR/JS events, keep waiting.
      return if @_processing > 0
      try
        unless is_done && is_done(window)
          # Not done and no events, so wait for the next timer.
          timers = (timer.next for timer in @_timers when timer.next)
          next = Math.min.apply(Math, timers)
          # If there are no timers, next is Infinity, larger then done_at, no waiting
          if next <= done_at
            return
        @_browser.emit "done", @_browser
        done()
      catch error
        @_browser.emit "error", error
        done(error)

    # No one is waiting, resume firing timers.
    @_resume() if @_waiting.length == 0
    @_waiting.push waiting
    @_next()
    return

  _next: ->
    for waiting in @_waiting
      process.nextTick waiting

  # Pause any timers from firing while we're not listening.
  _pause: ->
    for timer in @_timers when timer.next
      timer.pause()

  # Resumes any timers.
  _resume: ->
    for timer in @_timers when timer.next
      timer.resume()

  dump: ->
    return [ "The time:   #{new Date}",
             "Timers:     #{@_timers.length}",
             "Processing: #{@_processing}",
             "Waiting:    #{@_waiting.length}" ]


module.exports = EventLoop
