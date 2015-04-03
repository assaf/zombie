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


const assert            = require('assert');
const { EventEmitter }  = require('events');


// Wrapper for a timeout (setTimeout)
class Timeout {

  // eventQueue - Reference to the event queue
  // fn         - When timer fires, evaluate this function
  // delay      - How long to wait
  // remove     - Call this to discard timer
  //
  // Instance variables add:
  // handle  - Node.js timeout handle
  // next    - When is this timer firing next
  constructor(eventQueue, fn, delay, remove) {
    this.eventQueue   = eventQueue;
    this.fn           = fn;
    this.delay        = Math.max(delay || 0, 0);
    this.remove       = remove;

    this.handle       = global.setTimeout(this.fire.bind(this), this.delay);
    this.next         = Date.now() + this.delay;
  }

  fire() {
    // In response to Node firing setTimeout, but only allowed to process this
    // event during a wait()
    this.eventQueue.enqueue(()=> {
      const { eventLoop } = this.eventQueue;
      eventLoop.emit('setTimeout', this.fn, this.delay);
      try {
        this.eventQueue.window._evaluate(this.fn);
      } catch (error) {
        eventLoop.emit('error', error);
      }
    });
    this.remove();
  }

  // clearTimeout
  stop() {
    global.clearTimeout(this.handle);
    this.remove();
  }

}


// Wapper for an interval (setInterval)
class Interval {

  // eventQueue - Reference to the event queue
  // fn        - When timer fires, evaluate this function
  // interval  - Interval between firing
  // remove    - Call this to discard timer
  //
  // Instance variables add:
  // handle  - Node.js interval handle
  // next    - When is this timer firing next
  constructor(eventQueue, fn, interval, remove) {
    this.eventQueue     = eventQueue;
    this.fn             = fn;
    this.interval       = Math.max(interval || 0, 0);
    this.remove         = remove;
    this.fireInProgress = false;
    this.handle         = global.setInterval(this.fire.bind(this), this.interval);
    this.next           = Date.now() + this.interval;
  }

  fire() {
    // In response to Node firing setInterval, but only allowed to process this
    // event during a wait()
    this.next = Date.now() + this.interval;

    // setInterval events not allowed to overlap, don't queue two at once
    if (this.fireInProgress)
      return;
    this.fireInProgress = true;
    this.eventQueue.enqueue(()=> {
      this.fireInProgress = false;

      const { eventLoop } = this.eventQueue;
      eventLoop.emit('setInterval', this.fn, this.interval);
      try {
        this.eventQueue.window._evaluate(this.fn);
      } catch (error) {
        eventLoop.emit('error', error);
      }
    });
  }

  // clearTimeout
  stop() {
    global.clearInterval(this.handle);
    this.remove();
  }

}


// Each window has an event queue that holds all pending events.  Various
// browser features push new functions into the queue (e.g. process XHR
// response, setTimeout fires).  The event loop is responsible to pop these
// events from the queue and run them, but only during browser.wait().
//
// In addition, the event queue keeps track of all outstanding timers
// (setTimeout/setInterval) so it can return consecutive handles and clean them
// up during window.destroy().
//
// In addition, we keep track of when the browser is expecting an event to
// arrive in the queue (e.g. sent XHR request, expecting an event to process the
// response soon enough).  The event loop uses that to determine if it's worth
// waiting.
class EventQueue {

  // Instance variables:
  // browser          - Reference to the browser
  // eventLoop        - Reference to the browser's event loop
  // queue            - FIFO queue of functions to call
  // expecting        - These are holding back the event loop
  // timers           - Sparse array of timers (index is the timer handle)
  // eventSources     - Additional sources for events (SSE, WS, etc)
  // nextTimerHandle  - Value of next timer handler
  constructor(window) {
    this.window           = window;
    this.browser          = window.browser;
    this.eventLoop        = this.browser._eventLoop;
    this.queue            = [];
    this.expecting        = 0;
    this.timers           = [];
    this.eventSources     = [];
    this.nextTimerHandle  = 1;
  }


  // Cleanup when we dispose of the window
  destroy() {
    if (!this.queue)
      return;
    this.queue = null;

    for (let timer of this.timers) {
      if (timer)
        timer.stop();
    }
    this.timers = null;

    for (let eventSource of this.eventSources) {
      //if (eventSource)
        eventSource.close();
    }
    this.eventSources = null;
  }


  // -- Events --

  // Any events expected in the future?
  get expected() {
    return !!(this.expecting ||
              Array.from(this.window.frames).filter(frame => frame._eventQueue.expected).length);
  }

  // Add a function to the event queue, to be executed in order.
  enqueue(fn) {
    assert(this.queue, 'This browser has been destroyed');
    assert(typeof fn === 'function', 'eventLoop.enqueue called without a function');

    if (fn) {
      this.queue.push(fn);
      this.eventLoop.run();
    }
  }


  // Wait for completion.  Returns a completion function, event loop will remain
  // active until the completion function is called;
  waitForCompletion() {
    ++this.expecting;
    return ()=> {
      --this.expecting;
      setImmediate(()=> {
        this.eventLoop.run();
      });
    };
  }


  // Event loop uses this to grab event from top of the queue.
  dequeue() {
    assert(this.queue, 'This browser has been destroyed');

    const fn = this.queue.shift();
    if (fn)
      return fn;
    for (let frame of Array.from(this.window.frames)) {
      let childFn = frame._eventQueue.dequeue();
      if (childFn)
        return childFn;
    }
    return null;
  }


  // Makes an HTTP request.
  //
  // request  - Request object
  // callback - Called with Response object to process the response
  //
  // Because the callback is added to the queue, we can't use promises
  http(request, callback) {
    assert(this.queue, 'This browser has been destroyed');

    const done = this.waitForCompletion();
    this.window
      .fetch(request)
      .then((response)=> {
        // We can't cancel pending requests, but we can ignore the response if
        // window already closed
        if (this.queue)
          // This will get completion function to execute, e.g. to check a page
          // before meta tag refresh
          this.enqueue(()=> {
            callback(null, response);
          });
      })
      .catch((error)=> {
        if (this.queue)
          callback(error);
      })
      .then(done);
  }

  // Fire an error event.  Used by JSDOM patches.
  onerror(error) {
    assert(this.queue, 'This browser has been destroyed');

    this.eventLoop.emit('error', error);

    const event = this.window.document.createEvent('Event');
    event.initEvent('error', false, false);
    event.message = error.message;
    event.error = error;
    this.window.dispatchEvent(event);
  }


  // -- EventSource --

  addEventSource(eventSource) {
    assert(this.queue, 'This browser has been destroyed');

    this.eventSources.push(eventSource);

    const emit = eventSource.emit;
    eventSource.emit = (...args)=> {
      this.eventLoop.emit('serverEvent');
      this.enqueue(()=> {
        emit.apply(eventSource, args);
      });
    };
  }


  // -- Timers --

  // Window.setTimeout
  setTimeout(fn, delay = 0) {
    assert(this.queue, 'This browser has been destroyed');
    if (!fn)
      return null;

    const handle = this.nextTimerHandle;
    ++this.nextTimerHandle;
    this.timers[handle] = new Timeout(this, fn, delay, ()=> {
      delete this.timers[handle];
    });
    return handle;
  }

  // Window.clearTimeout
  clearTimeout(handle) {
    assert(this.queue, 'This browser has been destroyed');

    const timer = this.timers[handle];
    if (timer)
      timer.stop();
  }

  // Window.setInterval
  setInterval(fn, interval = 0) {
    assert(this.queue, 'This browser has been destroyed');
    if (!fn)
      return null;

    const handle = this.nextTimerHandle;
    ++this.nextTimerHandle;
    this.timers[handle] = new Interval(this, fn, interval, ()=> {
      delete this.timers[handle];
    });
    return handle;
  }

  // Window.clearInterval
  clearInterval(handle) {
    assert(this.queue, 'This browser has been destroyed');

    const timer = this.timers[handle];
    if (timer)
      timer.stop();
  }

  // Returns the timestamp of the next timer event
  get next() {
    const timers  = this.timers.map(timer => timer.next);
    const frames  = Array.from(this.window.frames).map(frame => frame._eventQueue.next);
    return timers.concat(frames).sort()[0] || Infinity;
  }

}


// The browser event loop.
//
// Each browser has one event loop that processes events from the queues of the
// currently active window and its frames (child windows).
//
// The wait method is responsible to process all pending events.  It goes idle
// once:
// - There are no more events waiting in the queue (of the active window)
// - There are no more timers waiting to fire (next -> Infinity)
// - No future events are expected to arrive (e.g. in-progress XHR requests)
//
// The wait method will complete before the loop goes idle, if:
// - Past the specified timeout
// - The next scheduled timer is past the specified timeout
// - The completio function evaluated to true
//
// While processing, the event loop emits the following events (on the browser
// object):
// tick(next) - Emitted after executing a single event; the argument is the
//              expected duration until the next event (in ms)
// idle       - Emitted when there are no more events (queued or expected)
// error(err) - Emitted after an error
module.exports = class EventLoop extends EventEmitter {

  // Instance variables are:
  // active    - Currently active window
  // browser   - Reference to the browser
  // running   - True when inside a run loop
  // waiting   - Counts in-progess calls to wait (waiters?)
  constructor(browser) {
    super();
    this.browser  = browser;
    this.active   = null;
    this.running  = false;
    this.waiting  = 0;
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
  //
  //
  // waitDuration       - How long to wait (ms)
  // completionFunction - Returns true for early completion
  wait(waitDuration, completionFunction, callback) {
    assert(waitDuration, 'Wait duration required, cannot be 0');
    const eventLoop = this;

    ++eventLoop.waiting;
    // Someone (us) just started paying attention, start processing events
    if (eventLoop.waiting === 1)
      setImmediate(()=> eventLoop.run());

    // The timer fires when we waited long enough, we need timeoutOn to tell if
    // the next event is past the wait duration and there's no point in waiting
    // further
    const timer     = global.setTimeout(timeout, waitDuration);  // eslint-disable-line no-use-before-define
    const timeoutOn = Date.now() + waitDuration;

    // Fired after every event, decide if we want to stop waiting
    function ontick(next) {
      // No point in waiting that long
      if (next >= timeoutOn) {
        timeout();
        return;
      }

      const activeWindow = eventLoop.active;
      if (completionFunction && activeWindow.document.documentElement)
        try {
          const waitFor   = Math.max(next - Date.now(), 0);
          // Event processed, are we ready to complete?
          const completed = completionFunction(activeWindow, waitFor);
          if (completed)
            done();
        } catch (error) {
          done(error);
        }

    }

    // The wait is over ...
    function done(error) {
      global.clearTimeout(timer);
      eventLoop.removeListener('tick', ontick);
      eventLoop.removeListener('idle', done);
      eventLoop.browser.removeListener('error', done);

      --eventLoop.waiting;
      callback(error);
    }

    // We gave up, could be result of slow response ...
    function timeout() {
      if (eventLoop.expected)
        done(new Error('Timeout: did not get to load all resources on this page'));
      else
        done();
    }

    eventLoop.on('tick', ontick);

    // Fired when there are no more events to process
    eventLoop.once('idle', done);

    // Stop on first error reported (document load, script, etc)
    // Event loop errors also propagated to the browser
    eventLoop.browser.once('error', done);
  }


  dump(output = process.stdout) {
    if (this.running)
      output.write('Event loop: running\n');
    else if (this.expected)
      output.write(`Event loop: waiting for ${this.expected} events\n`);
    else if (this.waiting)
      output.write('Event loop: waiting\n');
    else
      output.write('Event loop: idle\n');
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
    this.run(); // new window, new events?
  }

  // Are there any expected events for the active window?
  get expected() {
    return this.active && this.active._eventQueue.expected;
  }


  // -- Event processing --

  // Grabs next event from the queue, processes it and notifies all listeners.
  // Keeps processing until the queue is empty or all listeners are gone. You
  // only need to bootstrap this when you suspect it's not recursing.
  run() {
    // A lot of code calls run() without checking first, so not uncommon to have
    // concurrent executions of this function
    if (this.running)
      return;
    // Is there anybody out there?
    if (this.waiting === 0)
      return;

    // Give other (Node) events a chance to process
    this.running = true;
    setImmediate(()=> {
      this.running = false;
      try {

        // Are there any open windows?
        if (!this.active) {
          this.emit('idle');
          return;
        }
        // Don't run event outside browser.wait()
        if (this.waiting === 0)
          return;

        const jsdomQueue  = this.active.document._queue;
        const event       = this.active._eventQueue.dequeue();
        if (event) {
          // Process queued function, tick, and on to next event
          event();
          this.emit('tick', 0);
          this.run();
        } else if (this.expected > 0)
          // We're waiting for some events to come along, don't know when,
          // but they'll call run for us
          this.emit('tick', 0);
        else if (jsdomQueue.tail) {
          jsdomQueue.resume();
          this.run();
        } else {
          // All that's left are timers, and not even that if next == Infinity
          const next = this.active._eventQueue.next;
          if (isFinite(next))
            this.emit('tick', next);
          else
            this.emit('idle');
        }

      } catch (error) {
        this.emit('error', error);
      }
    });
  }

};

