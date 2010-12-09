class EventLoop
  constructor: (window)->
    window.clock = 0
    timers = {}
    lastHandle = 0
    queue = []
    # Implements window.setTimeout using event queue
    @setTimeout = (fn, delay)->
      timer = 
        when: window.clock + delay
        timeout: true
        fire: ->
          try
            if typeof fn == "function"
              fn.apply(window)
            else
              eval fn
          catch ex
            console.error "Timeout #{handle} failed", ex
          finally
            delete timers[handle]
      handle = ++lastHandle
      timers[handle] = timer
      handle
    # Implements window.setInterval using event queue
    @setInterval = (fn, delay)->
      timer = 
        when: window.clock + delay
        interval: true
        fire: ->
          try
            if typeof fn == "function"
              fn.apply(window)
            else
              eval fn
          catch ex
            console.error "Interval #{handle} failed", ex
            delete timers[handle]
          finally
            timer.when = window.clock + delay
      handle = ++lastHandle
      timers[handle] = timer
      handle
    # Implements window.clearTimeout using event queue
    @clearTimeout = (handle)-> delete timers[handle] if timers[handle]?.timeout
    # Implements window.clearInterval using event queue
    @clearInterval = (handle)-> delete timers[handle] if timers[handle]?.interval
    # Process all pending events and timers in the queue
    @process = (terminator)->
      next = ->
        return queue.shift() if queue.length > 0
        earliest = null
        for handle, timer of timers
          earliest = timer if !earliest || timer.when < earliest.when
        return unless earliest
        return ->
          window.clock = earliest.when
          earliest.fire()
      event = next()
      event() if event
      while event && terminator && terminator(window) != false
        event = next()
        event() if event
      return this
      ###
      while @queue.length > 0
        events = [].concat(@queue)
        @queue.clear
        for event in events
          console.log "firing", event
          event.apply(@window)
        for timer in @timers
          console.log "firing", timer
          timer.fire()
      ###
      #callback(clock)

# Apply event loop to window: creates new event loop and adds
# timeout/interval methods and XHR class.
exports.apply = (window)->
  eventLoop = new EventLoop(window)
  for fn in ["setTimeout", "setInterval", "clearTimeout", "clearInterval"]
    window[fn] = -> eventLoop[fn].apply(window, arguments)
  window.XMLHttpRequest = -> {}
  window.process = eventLoop.process
