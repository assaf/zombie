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


Domain            = require("domain")
{ EventEmitter }  = require("events")
ms                = require("ms")
{ Promise }       = require("bluebird")


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
class EventLoop extends EventEmitter

  # Instance variables are:
  # active    - The active window
  # browser   - Reference to the browser
  # expected  - Number of events expected to appear (see `expecting` method)
  # running   - True when inside a run loop
  # waiting   - Counts calls in-progess calls to wait
  constructor: (@browser)->
    @active   = null
    @expected = 0
    @running  = false
    @waiting  = 0
    @complex  = 0
    # Error in event loop propagates to browser
    @on "error", (error)=>
      @browser.emit("error", error)


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
    if waitDuration? or completionFunction?
      complex = true
      ++@complex

    # Don't wait longer than duration
    waitDuration ||= @browser.waitDuration
    waitDuration = ms(waitDuration.toString())
    timeoutOn = Date.now() + waitDuration

    # Someone (us) just started paying attention, start processing events
    ++@waiting
    if @waiting == 1
      setImmediate =>
        if @active
          @run()

    timer   = null
    ontick  = null
    onerror = null
    ondone  = null

    promise = new Promise((resolve, reject)=>
      timer = global.setTimeout(resolve, waitDuration)

      ontick = (next)=>
        if next >= timeoutOn
          # Next event too long in the future, or no events in queue
          # (Infinity), no point in waiting
          resolve()
        else if completionFunction && @active.document.documentElement
          try
            waitFor = Math.max(next - Date.now(), 0)
            # Event processed, are we ready to complete?
            completed = completionFunction(@active, waitFor)
            if completed
              resolve()
          catch error
            reject(error)
        return
      @on("tick", ontick)

      ondone  = resolve
      @once("done", ondone)


      # Don't wait if browser encounters an error (event loop errors also
      # propagate to browser)
      onerror = reject
      @browser.once("error", onerror)
      return
    )

    promise = promise.finally(=>
      
      clearInterval(timer)
      @removeListener("tick", ontick)
      @removeListener("done", ondone)
      @browser.removeListener("error", onerror)

      --@waiting
      if @waiting == 0
        @browser.emit("done")
      if complex
        --@complex
      return
    )

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
    return if @waiting == 0
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
          try
            fn()
            @emit("tick", 0)
            @run()
          catch error
            @emit("error", error)
        else if @expected > 0
          # We're waiting for some events to come along, don't know when,
          # but they'll call run for us
          @emit("tick", 0)
        else if @complex > 0 and @active._eventQueue.eventSources.length > 0
          # We're waiting for some events to come along,
          # and there are event sources on the page
          @emit("tick", 0)
        else
          # All that's left are timers
          nextTick = @active._eventQueue.next()
          @emit("tick", nextTick)
      catch error
        @emit("error", error)
    return


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
  # browser     - Reference to the browser
  # window      - Reference to the window
  # eventLoop   - Reference to the browser's event loop
  # expecting   - These are holding back the event loop
  # queue       - FIFO queue of functions to call
  # timers      - Sparse array of timers (index is the timer handle)
  # nextTimerHandle - Value of next timer handler
  constructor: (@window)->
    @browser = @window.browser
    @eventLoop = @browser.eventLoop
    @queue = []
    @expecting = []
    @timers           = []
    @eventSources = []
    @nextTimerHandle  = 1

  # Cleanup when we dispose of the window
  destroy: ->
    for timer in @timers
      timer.stop() if timer
    for expecting in @expecting
      expecting()
    for eventSource in @eventSources
      if eventSource
        eventSource.close()
    @timers = @queue = @expecting = @eventSources = null


  # -- Events --

  # Add a function to the event queue, to be executed in order.
  enqueue: (fn)->
    unless @queue
      throw new Error("This browser has been destroyed")
    if fn
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

        # Since this is used by resourceLoader that doesn't check the response,
        # we're responsible to turn anything other than 2xx/3xx into an error
        if response && response.statusCode >= 400
          error = new Error("Server returned status code #{response.statusCode} from #{url}")

        @enqueue =>
          callback error, response
          # Make sure browser gets a hold of this error and adds it to error list
          # This is necessary since resource loading (CSS, image, etc) does nothing
          # with the callback error
          if error
            @browser.emit("error", error)

      if @expecting
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


  # -- EventSource --

  addEventSource: (eventSource)->
    unless @eventSources
      throw new Error("This browser has been destroyed")

    @eventSources.push(eventSource)

    emit = eventSource.emit
    eventSource.emit = ()=>
      args = arguments
      @enqueue ->
        emit.apply(eventSource, args)


  # -- Timers --

  # Window.setTimeout
  setTimeout: (fn, delay = 0)->
    unless @timers
      throw new Error("This browser has been destroyed")
    return unless fn
    handle = @nextTimerHandle
    ++@nextTimerHandle
    remove = =>
      delete @timers[handle]
    @timers[handle] = new Timeout(this, fn, delay, remove)
    return handle

  # Window.clearTimeout
  clearTimeout: (handle)->
    unless @timers
      throw new Error("This browser has been destroyed")
    timer = @timers[handle]
    if timer
      timer.stop()
    return

  # Window.setInterval
  setInterval: (fn, interval = 0)->
    unless @timers
      throw new Error("This browser has been destroyed")
    return unless fn
    handle = @nextTimerHandle
    ++@nextTimerHandle
    remove = =>
      delete @timers[handle]
    @timers[handle] = new Interval(this, fn, interval, remove)
    return handle

  # Window.clearInterval
  clearInterval: (handle)->
    unless @timers
      throw new Error("This browser has been destroyed")
    timer = @timers[handle]
    if timer
      timer.stop()
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
        try
          @queue.window._evaluate(@fn)
        catch error
          @queue.browser.emit("error", error)
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
        try
          @queue.window._evaluate(@fn)
        catch error
          @queue.browser.emit("error", error)
    @handle = global.setInterval(fire, @interval)
    @next = Date.now() + @interval

  # clearTimeout
  stop: ->
    global.clearInterval(@handle)
    @remove()


module.exports = EventLoop
