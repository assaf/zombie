// Implements console.log, console.error, console.time, et al and emits a
// console event for each output.


const { format, inspect } = require('util');


module.exports = class Console {

  constructor(browser) {
    this.browser = browser;
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
    if (!this.counters)
      this.counters = {};
    if (!this.counters[name])
    this.counters[name] = 0;
    this.counters[name]++;
    const message = `${name}: ${this.counters[name]}`;
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
    if (!this.timers)
      this.timers = {};
    this.timers[name] = Date.now();
  }

  timeEnd(name) {
    if (this.timers) {
      const start = this.timers[name];
      delete this.timers[name];
      const message = `${name}: ${Date.now() - start}ms`;
      this.browser.emit('console', 'log', message);
    }
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

