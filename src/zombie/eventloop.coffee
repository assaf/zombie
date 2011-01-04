URL = require("url")


# Handles the Window event loop, timers and pending requests.
class EventLoop
  constructor: (browser)->
    timers = {}
    lastHandle = 0

    # ### window.setTimeout(fn, delay) => Number
    #
    # Implements window.setTimeout using event queue
    this.setTimeout = (fn, delay)->
      timer = 
        when: browser.clock + delay
        timeout: true
        fire: =>
          try
            if typeof fn == "function"
              fn.apply this
            else
              eval fn
          finally
            delete timers[handle]
      handle = ++lastHandle
      timers[handle] = timer
      handle

    # ### window.setInterval(fn, delay) => Number
    #
    # Implements window.setInterval using event queue
    this.setInterval = (fn, delay)->
      timer = 
        when: browser.clock + delay
        interval: true
        fire: =>
          try
            if typeof fn == "function"
              fn.apply this
            else
              eval fn
          finally
            timer.when = browser.clock + delay
      handle = ++lastHandle
      timers[handle] = timer
      handle

    # ### window.clearTimeout(timeout)
    #
    # Implements window.clearTimeout using event queue
    this.clearTimeout = (handle)-> delete timers[handle] if timers[handle]?.timeout
    # ### window.clearInterval(interval)
    #
    # Implements window.clearInterval using event queue
    this.clearInterval = (handle)-> delete timers[handle] if timers[handle]?.interval

    # Requests on wait that cannot be handled yet: there's no event in the
    # queue, but we anticipate one (in-progress XHR request).
    waiting = []
    # Queue of events.
    queue = []

    # ### wait(window, terminate, callback, intervals)
    #
    # Process all events from the queue. This method returns immediately, events
    # are processed in the background. When all events are exhausted, it calls
    # the callback with null, window; if any event fails, it calls the callback
    # with the exception.
    #
    # With one argument, that argument is the callback. With two arguments, the
    # first argument is a terminator and the last argument is the callback. The
    # terminator is one of:
    #
    # * null -- process all events
    # * number -- process that number of events
    # * function -- called after each event, stop processing when function
    #   returns false
    #
    # Events include timeout, interval and XHR onreadystatechange. DOM events
    # are handled synchronously.
    this.wait = (window, terminate, callback, intervals)->
      if !callback
        intervals = callback
        callback = terminate
        terminate = null
      process.nextTick =>
        earliest = null
        for handle, timer of timers
          continue if timer.interval && intervals == false
          earliest = timer if !earliest || timer.when < earliest.when
        if earliest
          intervals = false
          event = ->
            browser.clock = earliest.when if browser.clock < earliest.when
            earliest.fire()
        if event
          try 
            event()
            if typeof terminate is "number"
              --terminate
              if terminate <= 0
                process.nextTick -> callback null, window
                return
            else if typeof terminate is "function"
              if terminate.call(window) == false
                process.nextTick -> callback null, window
                return
            @wait window, terminate, callback, intervals
          catch err
            browser.emit "error", err
            callback err, window
        else if queue.length > 0
          waiting.push => @wait window, terminate, callback, intervals
        else
          browser.emit "drain", browser
          callback null, window

    # Used internally for the duration of an internal request (loading
    # resource, XHR). Also collects request/response for debugging.
    #
    # Function is called with request object and the function to be called
    # next. After storing the request, that function is called with a single
    # argument, a done callback. It must call the done callback when it
    # completes processing, passing error and response arguments.
    this.request = (request, fn)->
      url = request.url.toString()
      browser.log -> "#{request.method} #{url}"
      pending = browser.record request
      this.queue (done)->
        fn (err, response)->
          if err
            browser.log -> "Error loading #{url}: #{err}"
            pending.error = err
          else
            browser.log -> "#{request.method} #{url} => #{response.status}"
            pending.response = response
          done()

    queue = []
    # ### queue(event)
    #
    # Queue an event to be processed by wait(). Event is a function call in the
    # context of the window.
    this.queue = (fn)->
      queue.push fn
      fn ->
        queue.splice queue.indexOf(fn), 1
        if queue.length == 0
          for wait in waiting
            process.nextTick -> wait()
          waiting = []

    this.extend = (window)=>
      for fn in ["setTimeout", "setInterval", "clearTimeout", "clearInterval"]
        window[fn] = this[fn]
      window.queue = this.queue
      window.wait = (terminate, callback)=> this.wait(window, terminate, callback)
      window.request = this.request 

    this.dump = ()->
      dump = [ "The time: #{browser.clock}",
               "Timers:   #{timers.length}",
               "Queue:    #{queue.length}",
               "Waiting:  #{waiting.length}",
               "Requests:"]
      dump.push "  #{request}" for request in requests
      dump

exports.use = (browser)->
  return new EventLoop(browser)
