# The event loop.
#
# Each browser has an event loop, which processes asynchronous events like
# loading pages and resources, XHR, timeouts and intervals, etc. These are
# procesed in order.
#
# The purpose of the event loop is two fold:
# - To get events processed in the right order for the active window (and only
#   the active window)
# - And to allow the code to wait until all events have been processed
#   (browser.wait, .visit, .pressButton, etc)
#
# The event loop has one interesting method: `wait`.
#
# Each window maintains its own event queue. Its interesting methods are
# `enqueue`, `http`, `dispatch` and the timeout/interval methods.


ms  = require("ms")


# The browser event loop.
#
# All asynchronous events are processed by this one. The event loop monitors one
# event queue, of the currently active window, and executes its events. Other
# windows are suspended.
#
# Reason to wait for the event loop:
# - One or more events waiting in the queue to be processed
# - One or more timers waiting to fire
# - One or more future events, expected to arrive in the queue
#
# Reasons to stop waiting:
# - No more events in the queue, or expected to arrive
# - No more timers, or all timers are further than our timeout
# - Completion function evaluated to true
#
# The event loop emits the following events (on the browser):
# tick  - Emitted after executing an event; single argument is expected time
#         until next tick event (in ms, zero for "soon")
# done  - Emitted when the event queue is empty (may fire more than once)
# error - Emitted when an error occurs
class EventLoop

  # Instance variables are:
  # active    - The active window
  # browser   - Reference to the browser
  # expected  - Number of events expected to appear (see `expecting` method)
  # running   - True when inside a run loop
  # listeners - Array of listeners, used by wait method
  constructor: (@browser)->
    @active   = null
    @expected = 0
    @running  = false
    @listeners  = []


  # -- The wait function --

  # Wait until one of these happen:
  # 1. We run out of events to process; callback is called with null and false
  # 2. The completion function evaluates to true; callback is called with null
  #    and false
  # 3. The time duration elapsed; callback is called with null and true
  # 2. An error occurs; callback is called with an error
  #
  # Duration is specifies in milliseconds or string form (e.g. "15s").
  #
  # Completion function is called with the currently active window (may change
  # during page navigation or form submission) and returns true to stop waiting,
  # any other value to continue processing events.
  wait: (duration, completion, callback)->
    # Determines how long we're going to wait
    duration = ms(duration)
    waitFor = ms(@browser.waitFor)

    if @listeners.length == 0
      # Someone's paying attention, start processing events
      process.nextTick =>
        if @active
          @active._eventQueue.resume()
          @run()

    # Receive tick, done and error events
    listener = (event, value)=>
      switch event
        when "tick"
          # Event processed, are we ready to complete?
          if completion
            try
              completed = completion(@active)
            catch error
              done(error)
          # Should we keep waiting for next timer?
          if completed || value > Date.now() + waitFor
            done(null, true)
        when "done"
          done()
        when "error"
          done(value)
    @listeners.push(listener)

    timer = setTimeout(->
        done(null, true)
      , duration)

    # Cleanup listeners and times before calling callback
    done = (error, timedOut)=>
      clearTimeout(timer)
      @listeners.splice(@listeners.indexOf(listener), 1)
      callback(error, !!timedOut)

    return


  # -- Event queue management --

  # Creates and returns a new event queue (see EventQueue).
  createEventQueue: (window)->
    return new EventQueue(window)

  # Set the active window. Suspends processing events from any other window, and
  # switches to processing events from this window's queue.
  setActiveWindow: (window)->
    return if window == @active
    if @active
      @active._eventQueue.suspend()
    @active = window
    if @active
      @active._eventQueue.resume()
      @run() # new window, new events

  # Call this method when you know an event is coming, but don't have the event
  # yet. For example, when starting an HTTP request, and the event is for
  # processing the response.
  #
  # This method returns a continuation function that you must call eventually,
  # of the event loop will wait forever.
  expecting: ->
    ++@expected
    done = =>
      --@expected
      @run() # may be dead waiting for next event
      return
    return done


  # -- Event processing --

  # Grabs next event from the queue, processes it and notifies all listeners.
  # Keeps processing until the queue is empty or all listeners are gone. You
  # only need to bootstrap this when you suspect it's not recursing.
  run: ->
    # Are we in the midst of another run loop?
    return if @running
    # Is there anybody out there?
    return if @listeners.length == 0
    # Are there any open wndows?
    unless @active
      @emit("done")
      return

    # Give other (Node) events a chance to process
    @running = true
    process.nextTick =>
      @running = false
      unless @active
        @emit("done")
        return

      if fn = @active._eventQueue.dequeue()
        # Process queued function, tick, and on to next event
        try
          fn()
          @emit("tick", 0)
          @run()
        catch error
          @emit("error", error)
        return
      else
        # If there any point in waiting, and how long?
        # If there are no timers, are we expecting any new events?
        if time = @active._eventQueue.next()
          @emit("tick", time)
          @run()
        else if @expected == 0
          @emit("done")
        return
    return

  # Send to browser and listeners
  emit: (event, value)->
    @browser.emit(event, value)
    for listener in @listeners
      listener(event, value)


# Each window has an event queue that holds all pending events and manages
# timers.
#
# Each event is a function that gets called when it's the event time to fire.
# Various components push new functions to the queue, the event loop is
# reponsible for fetching the events and executing them.
#
# Timers are resumed when the window becomes active, suspened when the window
# becomes inactive, and execute by queuing events.
#
# HTTP request should use the `http` method, which uses `expecting` to indicate
# an event is expected while the request is in progress (so don't stop event
# loop), and queue the event when the response arrives.
class EventQueue

  # Instance variables:
  # browser   - Reference to the browser
  # window    - Reference to the window
  # eventLoop - Reference to the browser's event loop
  # queue     - FIFO queue of functions to call
  # timers    - Sparse array of timers (index is the timer handle)
  constructor: (@window)->
    @browser = @window.browser
    @eventLoop = @browser._eventLoop
    @timers = []
    @queue = []

  # Cleanup when we dispose of the window
  destroy: ->
    for timer in @timers
      if timer
        timer.stop()
    @timers = @queue = null


  # -- Events --
 
  # Add a function to the event queue, to be executed in order.
  enqueue: (fn)->
    if fn
      @queue.push(fn)
      @eventLoop.run()
    return

  # Event loop uses this to grab event from top of the queue.
  dequeue: ->
    if fn = @queue.shift()
      return fn
    for frame in @window.frames
      if fn = frame._eventQueue.dequeue()
        return fn
    return

  # Makes an HTTP request.
  #
  # Parameters are:
  # url     - URL (string)
  # method  - Method (defaults to GET)
  # headers - Headers to pass in request
  # data    - Document body
  #
  # Calls callback with response error or null and response object.
  http: (params, callback)->
    done = @eventLoop.expecting()
    @browser.resources._makeRequest params, (error, response)=>
      done()
      @enqueue ->
        callback error, response

  # Dispatch event synchronously, wait for it to complete. Returns true if
  # preventDefault was set.
  dispatch: (target, event)->
    preventDefault = false
    @window._evaluate ->
      preventDefault = target.dispatchEvent(event)
    return preventDefault

  # Fire an error event.
  onerror: (error)->
    @window.console.error(error)
    @browser.emit("error", error)
    event = @window.document.createEvent("Event")
    event.initEvent("error", false, false)
    event.message = error.message
    event.error = error
    @window.dispatchEvent(event)


  # -- Timers --

  # Window.setTimeout
  setTimeout: (fn, delay)->
    return unless fn
    index = @timers.length
    remove = =>
      delete @timers[index]
    timer = new Timeout(this, fn, delay, remove)
    @timers[index] = timer
    return index

  # Window.clearTimeout
  clearTimeout: (index)->
    timer = @timers[index]
    if timer
      timer.stop()
    return

  # Window.setInterval
  setInterval: (fn, interval)->
    return unless fn
    index = @timers.length
    remove = =>
      delete @timers[index]
    timer = new Interval(this, fn, interval, remove)
    @timers[index] = timer
    return index

  # Window.clearInterval
  clearInterval: (index)->
    timer = @timers[index]
    if timer
      timer.stop()
    return

  # Used when window goes out of focus, prevents timers from firing
  suspend: ->
    for timer in @timers
      if timer
        timer.suspend()

  # Used when window goes back in focus, resumes timers
  resume: ->
    for timer in @timers
      if timer
        timer.resume()

  # Returns the timestamp of the next timer event
  next: ->
    next = null
    for timer in @timers
      if timer && (!next || timer.next < next)
        next = timer.next
    for frame in @window.frames
      frameNext = frame._eventQueue.next()
      if frameNext && frameNext < next
        next = frameNext
    return next



# Wrapper for a timeout (setTimeout)
class Timeout

  # queue   - Reference to the event queue
  # fn      - When timer fires, evaluate this function
  # delay   - How long to wait
  # remove  - Call this to discard timer
  #
  # Instance variables add:
  # next    - When is this timer firing next
  # handle  - Node.js timeout handle
  constructor: (@queue, @fn, @delay, @remove)->
    @delay = Math.max(@delay || 0, 0)
    @resume()

  # Resume (also start) this timer
  resume: ->
    return if @handle # already resumed
    fire = =>
      @queue.enqueue =>
        @queue.browser.emit("timeout", @fn, @delay)
        @queue.window._evaluate(@fn)
      @remove()
    @handle = setTimeout(fire, Math.max(@next - Date.now(), 0))
    @next = Date.now() + @delay

  # Make sure timer doesn't fire until we're ready for it again
  suspend: ->
    global.clearTimeout(@handle)
    @handle = null

  # clearTimeout
  stop: ->
    global.clearTimeout(@handle)
    @remove()


# Wapper for an interval (setInterval)
class Interval

  # queue     - Reference to the event queue
  # fn        - When timer fires, evaluate this function
  # interval  - Interval between firing
  # remove    - Call this to discard timer
  #
  # Instance variables add:
  # next    - When is this timer firing next
  # handle  - Node.js interval handle
  constructor: (@queue, @fn, @interval, @remove)->
    @interval =  Math.max(@interval || 0)
    @resume()

  # Resume (also start) this timer
  resume: ->
    return if @handle # already resumed
    fire = =>
      @queue.enqueue =>
        @queue.browser.emit("interval", @fn, @interval)
        @queue.window._evaluate(@fn)
      @next = Date.now() + @interval
    @handle = setInterval(fire, @interval)
    @next = Date.now() + @interval

  # Make sure timer doesn't fire until we're ready for it again
  suspend: ->
    global.clearInterval(@handle)
    @handle = null

  # clearTimeout
  stop: ->
    global.clearInterval(@handle)
    @remove()


module.exports = EventLoop
