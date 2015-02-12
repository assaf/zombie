// The event loop.
//
// Each browser has an event loop, which processes asynchronous events like
// loading pages and resources, XHR, timeouts and intervals, etc. These are
// procesed in order.
//
// The purpose of the event loop is two fold:
// - To get events processed in the right order for the active window (and only
//   the active window)
// - And to allow the code to wait until all events have been processed
//   (browser.wait, .visit, .pressButton, etc)
//
// The event loop has one interesting method: `wait`.
//
// Each window maintains its own event queue. Its interesting methods are
// `enqueue`, `http`, `dispatch` and the timeout/interval methods.


const Domain            = require('domain');
const { EventEmitter }  = require('events');
const ms                = require('ms');
const { Promise }       = require('bluebird');
const Lazybird          = require('lazybird');


// Wrapper for a timeout (setTimeout)
class Timeout {

  // queue   - Reference to the event queue
  // fn      - When timer fires, evaluate this function
  // delay   - How long to wait
  // remove  - Call this to discard timer
  //
  // Instance variables add:
  // next    - When is this timer firing next
  // handle  - Node.js timeout handle
  constructor(queue, fn, delay, remove) {
    this.queue  = queue;
    this.fn     = fn;
    this.delay  = Math.max(delay || 0, 0);
    this.remove = remove;

    // When timeout fires, queue event for processing during a wait.
    const fire = ()=> {
      this.queue.enqueue(()=> {
        this.queue.browser.emit('timeout', this.fn, this.delay);
        try {
          this.queue.window._evaluate(this.fn);
        } catch (error) {
          this.queue.browser.emit('error', error);
        }
      });
      this.remove();
    };
    this.handle = global.setTimeout(fire, this.delay);
    this.next   = Date.now() + this.delay;
  }

  // clearTimeout
  stop() {
    global.clearTimeout(this.handle);
    this.remove();
  }

}


// Wapper for an interval (setInterval)
class Interval {

  // queue     - Reference to the event queue
  // fn        - When timer fires, evaluate this function
  // interval  - Interval between firing
  // remove    - Call this to discard timer
  //
  // Instance variables add:
  // next    - When is this timer firing next
  // handle  - Node.js interval handle
  constructor(queue, fn, interval, remove) {
    this.queue    = queue;
    this.fn       = fn;
    this.interval =  Math.max(interval || 0);
    this.remove   = remove;

    // When interval fires, queue event for processing during a wait.
    // Don't queue if already processing.
    let pendingEvent = false;
    const fire = ()=> {
      this.next = Date.now() + this.interval;
      if (pendingEvent)
        return;

      pendingEvent = true;
      this.queue.enqueue(()=> {
        pendingEvent = false;
        this.queue.browser.emit('interval', this.fn, this.interval);
        try {
          this.queue.window._evaluate(this.fn);
        } catch (error) {
          this.queue.browser.emit('error', error);
        }
      });
    };
    this.handle = global.setInterval(fire, this.interval);
    this.next = Date.now() + this.interval;
  }

  // clearTimeout
  stop() {
    global.clearInterval(this.handle);
    this.remove();
  }

}


// Each window has an event queue that holds all pending events and manages
// timers.
//
// Each event is a function that gets called when it's the event time to fire.
// Various components push new functions to the queue, the event loop is
// reponsible for fetching the events and executing them.
//
// Timers are resumed when the window becomes active, suspened when the window
// becomes inactive, and execute by queuing events.
//
// HTTP request should use the `http` method, which uses `expecting` to indicate
// an event is expected while the request is in progress (so don't stop event
// loop), and queue the event when the response arrives.
class EventQueue {

  // Instance variables:
  // browser     - Reference to the browser
  // window      - Reference to the window
  // eventLoop   - Reference to the browser's event loop
  // expecting   - These are holding back the event loop
  // queue       - FIFO queue of functions to call
  // timers      - Sparse array of timers (index is the timer handle)
  // nextTimerHandle - Value of next timer handler
  constructor(window) {
    this.window           = window;
    this.browser          = window.browser;
    this.eventLoop        = this.browser.eventLoop;
    this.queue            = [];
    this.expecting        = [];
    this.timers           = [];
    this.eventSources     = [];
    this.nextTimerHandle  = 1;
  }

  // Cleanup when we dispose of the window
  destroy() {
    this.queue = null;
    for (let timer of this.timers) {
      if (timer)
        timer.stop();
    }
    this.timers = null;
    for (let expecting of this.expecting)
      expecting();
    this.expecting = null;
    for (let eventSource of this.eventSources) {
      if (eventSource)
        eventSource.close();
    }
    this.eventSources = null;
  }


  // -- Events --

  // Add a function to the event queue, to be executed in order.
  enqueue(fn) {
    if (!this.queue)
      throw new Error('This browser has been destroyed');
    if (fn) {
      this.queue.push(fn);
      this.eventLoop.run();
    }
  }

  // Event loop uses this to grab event from top of the queue.
  dequeue() {
    if (!this.queue)
      return;
    const fn = this.queue.shift();
    if (fn)
      return fn;
    for (let frame of [...this.window.frames]) {
      let childFn = frame._eventQueue.dequeue();
      if (childFn)
        return childFn;
    }
    return null;
  }

  // Makes an HTTP request.
  //
  // Parameters are:
  // method   - Method (defaults to GET)
  // url      - URL (string)
  // options  - See below
  // callback - Called with error, or null and response
  //
  // Options:
  //   headers   - Name/value pairs of headers to send in request
  //   params    - Parameters to pass in query string or document body
  //   body      - Request document body
  //   timeout   - Request timeout in milliseconds (0 or null for no timeout)
  //
  // Calls callback with response error or null and response object.
  http(method, url, options, callback) {
    if (!this.queue)
      return;

    const done = this.eventLoop.expecting();
    this.expecting.push(done);

    this.browser.resources.request(method, url, options, (error, response)=> {
      // We can't cancel pending requests, but we can ignore the response if
      // window already closed
      if (this.queue) {

        // Since this is used by resourceLoader that doesn't check the response,
        // we're responsible to turn anything other than 2xx/3xx into an error
        if (response && response.statusCode >= 400)
          error = new Error(`Server returned status code ${response.statusCode} from ${url}`);

        this.enqueue(()=> {
          callback(error, response);
          // Make sure browser gets a hold of this error and adds it to error list
          // This is necessary since resource loading (CSS, image, etc) does nothing
          // with the callback error
          if (error)
            this.browser.emit('error', error);
        });
      }

      if (this.expecting) {
        this.expecting.splice(this.expecting.indexOf(done), 1);
        done();
      }
    });
  }

  // Fire an error event.
  onerror(error) {
    this.browser.emit('error', error);

    const event = this.window.document.createEvent('Event');
    event.initEvent('error', false, false);
    event.message = error.message;
    event.error = error;
    this.window.dispatchEvent(event);
  }


  // -- EventSource --

  addEventSource(eventSource) {
    if (!this.eventSources)
      throw new Error('This browser has been destroyed');

    this.eventSources.push(eventSource);

    const emit = eventSource.emit;
    eventSource.emit = (...args)=> {
      this.eventLoop.emit('server');
      this.enqueue(()=> {
        emit.apply(eventSource, args);
      });
    };
  }


  // -- Timers --

  // Window.setTimeout
  setTimeout(fn, delay = 0) {
    if (!this.timers)
      throw new Error('This browser has been destroyed');
    if (!fn)
      return;

    const handle = this.nextTimerHandle;
    ++this.nextTimerHandle;
    const remove = ()=> {
      delete this.timers[handle];
    };
    this.timers[handle] = new Timeout(this, fn, delay, remove);
    return handle;
  }

  // Window.clearTimeout
  clearTimeout(handle) {
    if (!this.timers)
      throw new Error('This browser has been destroyed');
    const timer = this.timers[handle];
    if (timer)
      timer.stop();
  }

  // Window.setInterval
  setInterval(fn, interval = 0) {
    if (!this.timers)
      throw new Error('This browser has been destroyed');
    if (!fn)
      return;

    const handle = this.nextTimerHandle;
    ++this.nextTimerHandle;
    const remove = ()=> {
      delete this.timers[handle];
    };
    this.timers[handle] = new Interval(this, fn, interval, remove);
    return handle;
  }

  // Window.clearInterval
  clearInterval(handle) {
    if (!this.timers)
      throw new Error('This browser has been destroyed');
    const timer = this.timers[handle];
    if (timer)
      timer.stop();
  }

  // Returns the timestamp of the next timer event
  next() {
    let next = Infinity;
    for (let timer of this.timers) {
      if (timer && timer.next < next)
        next = timer.next;
    }
    for (let frame of [...this.window.frames]) {
      let frameNext = frame._eventQueue.next();
      if (frameNext < next)
        next = frameNext;
    }
    return next;
  }

}


// The browser event loop.
//
// All asynchronous events are processed by this one. The event loop monitors one
// event queue, of the currently active window, and executes its events. Other
// windows are suspended.
//
// Reason to wait for the event loop:
// - One or more events waiting in the queue to be processed
// - One or more timers waiting to fire
// - One or more future events, expected to arrive in the queue
//
// Reasons to stop waiting:
// - No more events in the queue, or expected to arrive
// - No more timers, or all timers are further than our timeout
// - Completion function evaluated to true
//
// The event loop emits the following events (on the browser):
// tick  - Emitted after executing an event; single argument is expected time
//         until next tick event (in ms, zero for "soon")
// done  - Emitted when the event queue is empty (may fire more than once)
// error - Emitted when an error occurs
module.exports = class EventLoop extends EventEmitter {

  // Instance variables are:
  // active    - The active window
  // browser   - Reference to the browser
  // expected  - Number of events expected to appear (see `expecting` method)
  // running   - True when inside a run loop
  // waiting   - Counts calls in-progess calls to wait
  constructor(browser) {
    this.browser  = browser;
    this.active   = null;
    this.expected = 0;
    this.running  = false;
    this.waiting  = 0;
    // Error in event loop propagates to browser
    this.on('error', (error)=> {
      this.browser.emit('error', error);
    });
  }


  // -- The wait function --

  // Wait until one of these happen:
  // 1. We run out of events to process; callback is called with null and false
  // 2. The completion function evaluates to true; callback is called with null
  //    and false
  // 3. The time duration elapsed; callback is called with null and true
  // 2. An error occurs; callback is called with an error
  //
  // Duration is specifies in milliseconds or string form (e.g. "15s").
  //
  // Completion function is called with the currently active window (may change
  // during page navigation or form submission) and how long until the next
  // event, and returns true to stop waiting, any other value to continue
  // processing events.
  wait(waitDuration, completionFunction) {
    // Don't wait longer than duration
    waitDuration = ms(waitDuration.toString()) || this.browser.waitDuration;
    const timeoutOn = Date.now() + waitDuration;
    const eventLoop = this;

    const lazy = new Lazybird((resolve, reject)=> {
      // Someone (us) just started paying attention, start processing events
      ++eventLoop.waiting;
      if (eventLoop.waiting === 1)
        setImmediate(()=> eventLoop.run());

      let finished  = false;
      let timer     = global.setTimeout(resolve, waitDuration);

      function ontick(next) {
        if (next >= timeoutOn) {
          // Next event too long in the future, or no events in queue
          // (Infinity), no point in waiting
          done();
          return;
        }

        const activeWindow = eventLoop.active;
        if (completionFunction && activeWindow.document.documentElement) {
          try {
            const waitFor = Math.max(next - Date.now(), 0);
            // Event processed, are we ready to complete?
            const completed = completionFunction(activeWindow, waitFor);
            if (completed)
              done();
          } catch (error) {
            done(error);
          }
        }
      }
      eventLoop.on('tick', ontick);

      eventLoop.once('done', done);
      // Don't wait if browser encounters an error (event loop errors also
      // propagate to browser)
      eventLoop.browser.once('error', done);
        
      function done(error) {
        if (finished)
          return;
        finished = true;

        clearInterval(timer);
        eventLoop.removeListener('tick', ontick);
        eventLoop.removeListener('done', done);
        eventLoop.browser.removeListener('error', done);

        --eventLoop.waiting;
        if (eventLoop.waiting === 0)
          eventLoop.browser.emit('done');
        if (error)
          reject(error);
        else
          resolve();
      }
    });
    return lazy;
  }


  dump() {
    return [];
  }

  // -- Event queue management --

  // Creates and returns a new event queue (see EventQueue).
  createEventQueue(window) {
    return new EventQueue(window);
  }

  // Set the active window. Suspends processing events from any other window, and
  // switches to processing events from this window's queue.
  setActiveWindow(window) {
    if (window === this.active)
      return;
    this.active = window;
    if (this.active);
      this.run(); // new window, new events
  }

  // Call this method when you know an event is coming, but don't have the event
  // yet. For example, when starting an HTTP request, and the event is for
  // processing the response.
  //
  // This method returns a continuation function that you must call eventually,
  // of the event loop will wait forever.
  expecting() {
    ++this.expected;
    const done = ()=> {
      --this.expected;
      this.run(); // may be dead waiting for next event
    };
    return done;
  }


  // Cross-breed between expecting() and process.nextTick.  Executes the function
  // in the next tick, but makes sure waiters block for the function.
  next(fn) {
    ++this.expected;
    setImmediate(()=> {
      --this.expected;
      try {
        fn();
        this.run();
      } catch (error) {
        this.emit('error', error);
      }
    });
  }


  // -- Event processing --

  // Grabs next event from the queue, processes it and notifies all listeners.
  // Keeps processing until the queue is empty or all listeners are gone. You
  // only need to bootstrap this when you suspect it's not recursing.
  run() {
    // Are we in the midst of another run loop?
    if (this.running)
      return;
    // Is there anybody out there?
    if (this.waiting === 0)
      return;
    // Are there any open windows?
    if (!this.active) {
      this.emit('done');
      return;
    }

    // Give other (Node) events a chance to process
    this.running = true;
    setImmediate(()=> {
      this.running = false;
      if (!this.active || this.waiting === 0) {
        this.emit('done');
        return;
      }

      try {
        const fn = this.active._eventQueue.dequeue();
        if (fn) {
          // Process queued function, tick, and on to next event
          try {
            fn();
            this.emit('tick', 0);
            this.run();
          } catch (error) {
            this.emit('error', error);
          }
        } else if (this.expected > 0) {
          // We're waiting for some events to come along, don't know when,
          // but they'll call run for us
          this.emit('tick', 0);
        } else {
          // All that's left are timers
          const nextTick = this.active._eventQueue.next();
          this.emit('tick', nextTick);
        }
      } catch (error) {
        this.emit('error', error);
      }
    });
  }

}

