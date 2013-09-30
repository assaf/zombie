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
Q   = require("q")
global.setImmediate ||= process.nextTick


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
  # during page navigation or form submission) and how long until the next
  # event, and returns true to stop waiting, any other value to continue
  # processing events.
  wait: (waitDuration, completionFunction)->
    deferred = Q.defer()
    promise = deferred.promise

    # Don't wait longer than duration
    waitDuration = ms(waitDuration.toString()) || @browser.waitDuration
    timeout = Date.now() + waitDuration

    timeoutTimer = global.setTimeout(->
      deferred.resolve()
    , waitDuration)

    # Map event type to event handler
    eventHandlers =
      tick: (next)=>
        if next >= timeout
          # Next event too long in the future, or no events in queue
          # (Infinity), no point in waiting
          deferred.resolve()
        else if completionFunction && @active.document.documentElement
          try
            waitFor = Math.max(next - Date.now(), 0)
            # Event processed, are we ready to complete?
            completed = completionFunction(@active, waitFor)
            if completed
              deferred.resolve()
          catch error
            deferred.reject(error)
        return
      done:  deferred.resolve
      error: deferred.reject

    # Receive tick, done and error events
    listener = (event, argument)->
      eventHandlers[event](argument)
    @listeners.push(listener)

    # Don't wait if browser encounters an error.
    @browser.addListener("error", deferred.reject)

    # Whether resolved or rejected, clear timeouts/listeners
    removeListener = =>
      clearTimeout(timeoutTimer)
      @browser.removeListener("error", deferred.reject)
      @listeners = @listeners.filter((l)-> l != listener)
      if @listeners.length == 0
        @emit("done")
      return
    promise.finally(removeListener)

    # Someone (us) just started paying attention, start processing events
    if @listeners.length == 1
      setImmediate =>
        if @active
          @run()

    return promise

  dump: ()->
  	[]

  # -- Event queue management --

  # Creates and returns a new event queue (see EventQueue).
  createEventQueue: (window)->
    return new EventQueue(window)

  # Set the active window. Suspends processing events from any other window, and
  # switches to processing events from this window's queue.
  setActiveWindow: (window)->
    return if window == @active
    @active = window
    if @active
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


  # Cross-breed between expecting() and process.nextTick.  Executes the function
  # in the next tick, but makes sure waiters block for the function.
  next: (fn)->
    ++@expected
    setImmediate =>
      --@expected
      try
        fn()
        @run()
      catch error
        @emit("error", error)


  # -- Event processing --

  # Grabs next event from the queue, processes it and notifies all listeners.
  # Keeps processing until the queue is empty or all listeners are gone. You
  # only need to bootstrap this when you suspect it's not recursing.
  run: ->
    # Are we in the midst of another run loop?
    return if @running
    # Is there anybody out there?
    return if @listeners.length == 0
    # Are there any open windows?
    unless @active
      @emit("done")
      return

    # Give other (Node) events a chance to process
    @running = true
    setImmediate =>
      @running = false
      unless @active
        @emit("done")
        return

      try
        if fn = @active._eventQueue.dequeue()
          # Process queued function, tick, and on to next event
          fn()
          @emit("tick", 0)
          @run()
        else if @expected > 0
          # We're waiting for some events to come along, don't know when,
          # but they'll call run for us
          @emit("tick", 0)
        else
          # All that's left are timers
          time = @active._eventQueue.next()
          @emit("tick", time)
          @run()
      catch error
        @emit("error", error)
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
  # expecting - These are holding back the event loop
  # queue     - FIFO queue of functions to call
  # timers    - Sparse array of timers (index is the timer handle)
  constructor: (@window)->
    @browser = @window.browser
    @eventLoop = @browser.eventLoop
    @timers = []
    @queue = []
    @expecting = []

  # Cleanup when we dispose of the window
  destroy: ->
    for timer in @timers
      timer.stop() if timer
    for expecting in @expecting
      expecting()
    @timers = @queue = @expecting = null


  # -- Events --

  # Add a function to the event queue, to be executed in order.
  enqueue: (fn)->
    if fn && @queue
      @queue.push(fn)
      @eventLoop.run()
    return

  # Event loop uses this to grab event from top of the queue.
  dequeue: ->
    return unless @queue
    if fn = @queue.shift()
      return fn
    for frame in @window.frames
      if fn = frame._eventQueue.dequeue()
        return fn
    return

  # Makes an HTTP request.
  #
  # Parameters are:
  # method   - Method (defaults to GET)
  # url      - URL (string)
  # options  - See below
  # callback - Called with error, or null and response
  #
  # Options:
  #   headers   - Name/value pairs of headers to send in request
  #   params    - Parameters to pass in query string or document body
  #   body      - Request document body
  #   timeout   - Request timeout in milliseconds (0 or null for no timeout)
  #
  # Calls callback with response error or null and response object.
  http: (method, url, options, callback)->
    return unless @queue
    done = @eventLoop.expecting()
    @expecting.push(done)
    @browser.resources.request method, url, options, (error, response)=>
      # We can't cancel pending requests, but we can ignore the response if
      # window already closed
      if @queue
        @enqueue ->
          callback error, response
        @expecting.splice(@expecting.indexOf(done), 1)
        done()
    return

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
  setTimeout: (fn, delay = 0)->
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
    timer.stop() if timer
    return

  # Window.setInterval
  setInterval: (fn, interval = 0)->
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
    timer.stop() if timer
    return

  # Returns the timestamp of the next timer event
  next: ->
    next = Infinity
    for timer in @timers
      if timer && timer.next < next
        next = timer.next
    for frame in @window.frames
      frameNext = frame._eventQueue.next()
      if frameNext < next
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
    # When timeout fires, queue event for processing during a wait.
    fire = =>
      @queue.enqueue =>
        @queue.browser.emit("timeout", @fn, @delay)
        @queue.window._evaluate(@fn)
      @remove()
    @handle = global.setTimeout(fire, @delay)
    @next = Date.now() + @delay

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
    # When interval fires, queue event for processing during a wait.
    # Don't queue if already processing.
    pendingEvent = false
    fire = =>
      @next = Date.now() + @interval
      if pendingEvent
        return
      pendingEvent = true
      @queue.enqueue =>
        pendingEvent = false
        @queue.browser.emit("interval", @fn, @interval)
        @queue.window._evaluate(@fn)
    @handle = global.setInterval(fire, @interval)
    @next = Date.now() + @interval

  # clearTimeout
  stop: ->
    global.clearInterval(@handle)
    @remove()


module.exports = EventLoop
