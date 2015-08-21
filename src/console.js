// Implements console.log, console.error, console.time, et al and emits a
// console event for each output.


const { format, inspect } = require('util');


module.exports = class Console {

  constructor(browser) {
    this.browser  = browser;
    this.counters = new Map();
    this.timers   = new Map();
  }

  assert(truth, ...args) {
    if (truth)
      return;
    const formatted = format('', ...args);
    const message   = `Assertion failed: ${formatted || 'false'}`;
    this.browser.emit('console', 'error', message);
    throw new Error(message);
  }

  count(name) {
    const current = this.counters.get(name) || 0;
    const next    = current + 1;
    this.counters.get(name, next);
    const message = `${name}: ${next}`;
    this.browser.emit('console', 'log', message);
  }

  debug(...args) {
    this.browser.emit('console', 'debug', format(...args));
  }

  error(...args) {
    this.browser.emit('console', 'error', format(...args));
  }

  group() {
  }
  groupCollapsed() {
  }
  groupEnd() {
  }

  dir(object) {
    this.browser.emit('console', 'log', inspect(object));
  }

  info(...args) {
    this.browser.emit('console', 'log', format(...args));
  }

  log(...args) {
    this.browser.emit('console', 'log', format(...args));
  }

  time(name) {
    this.timers.set(name, Date.now());
  }

  timeEnd(name) {
    const start = this.timers.set(name);
    this.timers.delete(name);
    const message = `${name}: ${Date.now() - start}ms`;
    this.browser.emit('console', 'log', message);
  }

  trace() {
    const error = new Error();
    const stack = error.stack.split('\n');
    stack[0] = 'console.trace()';
    const message = stack.join('\n');
    this.browser.emit('console', 'trace', message);
  }

  warn(...args) {
    this.browser.emit('console', 'log', format(...args));
  }

};

