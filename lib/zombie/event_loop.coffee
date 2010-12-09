class EventLoop
  constructor: (@window)->
    @clock = 0
    @timers = []
    @lastHandle = 0
    @queue = []
  # Implements window.setTimeout using event queue
  setTimeout: (fn, delay)->
    timer = 
      when: clock + delay
      fire: ->
        try
          if typeof fn == "function"
            fn.apply(@window)
          else
            eval fn
        catch ex
          console.error "setTimeout", ex
        finally
          delete @timers[handle]
    handle = ++@lastHandle
    @timers[handle] = timer
    handle
  # Implements window.setInterval using event queue
  setInterval: (fn, delay)->
    timer = 
      when: clock + delay
      fire: ->
        try
          if typeof fn == "function"
            fn.apply(@window)
          else
            eval fn
        catch ex
          console.error "setInterval", ex
          delete @timers[handle]
        finally
          timer.when = clock + delay
    handle = ++@lastHandle
    @timers[handle] =
    handle
  # Implements window.clearTimeout using event queue
  clearTimeout: (handle)-> delete @timers[handle]
  # Implements window.clearInterval using event queue
  clearInterval: (handle)-> delete @timers[handle]
  # Process all pending events and timers in the queue
  process: (callback)->
    while @queue.length > 0
      events = [].concat(@queue)
      @queue.clear
      for event in events
        console.log "firing", event
        event.apply(@window)
      for timer in @timers
        console.log "firing", timer
        timer.fire()
    callback(@clock)

# Apply event loop to window: creates new event loop and adds
# timeout/interval methods and XHR class.
exports.apply = (window)->
  eventLoop = new EventLoop(window)
  window._eventLoop = eventLoop
  for fn in ["setTimeout", "setInterval", "clearTimeout", "clearInterval"]
    window[fn] = eventLoop[fn]
  # TODO: XHR
  window.XMLHttpRequest = -> {}
  # TODO: process method
