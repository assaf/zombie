# The event loop.
#
# Each window has its own event loop, which tracks timeouts and intervals,
# and incomplete asynchronous events (XHR, script loading, etc).


ms  = require("ms")
URL = require("url")
{ raise } = require("./scripts")


# Handles the Window event loop, timers and pending requests.
class EventLoop

  constructor: (@window)->
    @browser = @window.browser
    # Size of processing queue (number of ongoing tasks).
    @processing = 0
    # Requests on wait that cannot be handled yet: there's no event in the queue, but we anticipate one (in-progress XHR
    # request).
    @waiting = []
    @timers = []
    # Add setTimeout, setInterval, et al to window object
    @apply(@window)

  # Reset the event loop (clearning any timers, etc) before using a new window.
  reset: ->
    # Prevent any existing timers from firing.
    if @timers
      for timer in @timers
        global.clearTimeout timer.handle
    @timers = []
  
  # Add event-loop features to window (mainly timers).
  apply: (window)->
    # Remove timer.
    remove = (timer)=>
      index = @timers.indexOf(timer)
      @timers.splice(index, 1) if ~index

    # Add new timeout.  If the timeout is short enough, we ask `wait` to automatically wait for it to fire, by storing
    # the time in `timer.next`.  We need to clear `next` after the timer fires or when cancelled.
    window.setTimeout = (fn, delay)=>
      return unless fn
      timer =
        handle: null
        timeout: true
        # Resume timer: when created, and when entering browser.wait again.
        resume: =>
          return if timer.handle
          timer.next = Date.now() + Math.max(delay || 0, 0)
          if delay <= 0
            # Something weird happens if we use setTimeout(fn, 0), seems that the timer never fires
            remove(timer)
            @perform (done)=>
              process.nextTick =>
                @browser.log "Firing timeout after #{delay}ms delay"
                window._evaluate fn
                done()
          else
            timer.handle = global.setTimeout(=>
              @perform (done)=>
                remove(timer)
                @browser.log "Firing timeout after #{delay}ms delay"
                window._evaluate fn
                done()
            , delay)

        pause: ->
          # Pause timer when leaving browser.wait.  Reset remaining delay so we
          # start fresh on next browser.wait.
          global.clearTimeout(timer.handle)
          timer.handle = null
          delay = timer.next - Date.now()
        stop: ->
          global.clearTimeout(timer.handle)
          remove(timer)
      # Add timer and start the clock.
      @timers.push timer
      timer.resume()
      return timer

    window.setInterval = (fn, interval = 0)=>
      return unless fn
      timer =
        handle: null
        interval: true
        resume: => # Resume timer when entering browser.wait.
          return if timer.handle
          timer.next = Date.now() + interval
          timer.handle = global.setInterval(=>
            @perform (done)=>
              timer.next = Date.now() + interval
              @browser.log "Firing interval every #{interval}ms"
              window._evaluate fn
              done()
          , interval)
        pause: -> # Pause timer when leaving browser.wait.
          # Pause timer when leaving browser.wait.  Reset remaining delay so we
          global.clearInterval(timer.handle)
          timer.handle = null
        stop: ->
          global.clearInterval(timer.handle)
          remove(timer)
      # Add timer and start the clock.
      @timers.push timer
      timer.resume()
      return timer

    window.clearTimeout = (timer)->
      if timer && timer.timeout && timer.stop
        timer.stop()
    window.clearInterval = (timer)->
      if timer && timer.interval && timer.stop
        timer.stop()


  # ### perform(fn)
  #
  # Run the function as part of the event queue (calls to `wait` will wait for this function to complete).  Function can
  # be anything and is called synchronous with a `done` function; when it's done processing, it lets the event loop know
  # by calling the done function.
  perform: (fn)->
    ++@processing
    fn =>
      --@processing
      if @processing == 0
        @next()
    return

  # Dispatch event asynchronously, wait for it to complete.  Returns true if
  # preventDefault was set.
  dispatch: (target, event)->
    preventDefault = false
    @perform (done)->
      if target._evaluate 
        window = target
      else
        window = (target.ownerDocument || target.document).window
      window._evaluate ->
        preventDefault = target.dispatchEvent(event)
      done()
    return preventDefault

  # Makes a request.  Requires HTTP method and resource URL.
  #
  # Optional data object is used to construct query string parameters
  # or request body (e.g submitting a form).
  #
  # Optional headers are passed to the server.  When making a POST/PUT
  # request, you probably want specify the `content-type` header.
  #
  # The callback is called with error and response (see `HTTPResponse`).
  request: (params, callback)->
    resources = @browser.resources
    this.perform (done)->
      resources._makeRequest params, (error, response)->
        callback error, response
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
        duration = @browser.waitFor
      done_at = Date.now() + ms(duration || 0)

    # Called once at the end of the loop. Also, set to null when done, since
    # waiting may be called multiple times.
    done = (error)=>
      # Mark as done so we don't run it again.
      done = null
      # Remove from waiting list, pause timers if last waiting.
      @waiting = (fn for fn in @waiting when fn != waiting)
      @pause() if @waiting.length == 0
      if terminate
        clearTimeout(terminate)

      # Callback and event emitter, pick your poison.
      if callback
        process.nextTick ->
          callback error, window
      if error
        @browser.emit "error", error
      else
        @browser.emit "done"

    # don't block forever
    terminate = setTimeout(done, ms(@browser.maxWait))

    # Duration is a function, proceed until function returns false.
    waiting = =>
      # May be called multiple times from nextTick
      return unless done
      # Processing XHR/JS events, keep waiting.
      return if @processing > 0
      try
        if is_done && is_done(window)
          done() # Yay
          return
      catch error # Propagate
        done(error)
        return

      # not done and no events, so wait for the next timer.
      timers = (timer.next for timer in @timers)
      next = Math.min(timers...)
      # if there are no timers, next is infinity, larger then done_at, no waiting
      if next > done_at
        done()

    # No one is waiting, resume firing timers.
    @resume() if @waiting.length == 0
    @waiting.push waiting
    @next()
    return

  # Kick off all the waiting callbacks.
  next: ->
    for waiting in @waiting
      process.nextTick waiting
    return

  # Pause any timers from firing while we're not listening.
  pause: ->
    for timer in @timers
      timer.pause()
    return

  # Resumes any timers.
  resume: ->
    # Note: timer.resume modifies _timers
    for timer in @timers.slice()
      timer.resume()
    return

  dump: ->
    return [ "The time:   #{new Date}",
             "Timers:     #{@timers.length}",
             "Processing: #{@processing}",
             "Waiting:    #{@waiting.length}" ]


module.exports = EventLoop
