class EventLoop
  constructor: (window)->
    window.clock = 0
    timers = {}
    lastHandle = 0

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
          finally
            timer.when = window.clock + delay
      handle = ++lastHandle
      timers[handle] = timer
      handle
    # Implements window.clearTimeout using event queue
    @clearTimeout = (handle)-> delete timers[handle] if timers[handle]?.timeout
    # Implements window.clearInterval using event queue
    @clearInterval = (handle)-> delete timers[handle] if timers[handle]?.interval

    # Requests on wait that cannot be handled yet: there's no event in the
    # queue, but we anticipate one (in-progress XHR request).
    waiting = []
    # Queue of events.
    queue = []

    # Queue an event to be processed by wait(). Event is a function call in the
    # context of the window.
    @queue = (event)->
      queue.push event
      wait() for wait in waiting
      waiting = []

    # Process all events from the queue. This method returns immediately, events
    # are processed in the background. When all events are exhausted, it calls
    # the callback with null, window; if any event fails, it calls the callback
    # with the exception.
    #
    # Events include timeout, interval and XHR onreadystatechange. DOM events
    # are handled synchronously.
    @wait = (count, callback)->
      if typeof count is "function"
        if !callback
          callback = count
          count = null
        else
          count = count()
      if typeof count is "number" && count <= 0
        callback null, window
        return
      --count if count
      process.nextTick =>
        unless event = queue.shift()
          earliest = null
          for handle, timer of timers
            earliest = timer if !earliest || timer.when < earliest.when
          if earliest
            event = ->
              window.clock = earliest.when
              earliest.fire()
        if event
          try 
            event.call(window)
            @wait count, callback
          catch err
            callback err, window
        else if window._xhr > 0
          waiting.push => @wait count, callback
        else
          callback null, window


# Apply event loop to window: creates new event loop and adds
# timeout/interval methods and XHR class.
exports.apply = (window)->
  eventLoop = new EventLoop(window)
  for fn in ["setTimeout", "setInterval", "clearTimeout", "clearInterval"]
    window[fn] = -> eventLoop[fn].apply(window, arguments)
  window.process = eventLoop.process
  window.queue = eventLoop.queue
  window.wait = eventLoop.wait
