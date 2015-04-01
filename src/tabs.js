// Tab management.

const _             = require('lodash');
const createHistory = require('./history');


module.exports = class Tabs extends Array {

  constructor(browser) {
    super();
    this._current = null;
    this._browser = browser;
    this.length   = 0;
    Object.defineProperty(this, 'length',   { enumerable: false, writable: true });
    Object.defineProperty(this, '_browser', { enumerable: false, writable: true });
    Object.defineProperty(this, '_current', { enumerable: false, writable: true });
  }

  // Get the currently open tab
  get current() {
    return this._current;
  }

  // Sets the currently open tab
  // - Name   - Pick existing window with this name
  // - Number - Pick existing window from tab position
  // - Window - Use this window
  set current(nameOrWindow) {
    const window = this.find(nameOrWindow);
    if (this._indexOf(window) < 0)
      return;
    if (!Tabs.sameWindow(this._current, window)) {
      if (this._current)
        this._browser.emit('inactive', this._current);
      this._current = window;
      this._browser.emit('active', this._current);
    }
  }

  // Returns window by index or name. Use this for window names that shadow
  // existing properties (e.g. tabs['open'] is a function, use
  find(nameOrWindow) {
    if (this.propertyIsEnumerable(nameOrWindow))
      return this[nameOrWindow];
    const byName = _.find(this, { name: nameOrWindow });
    if (byName)
      return byName;
    if (this._indexOf(nameOrWindow) >= 0)
      return nameOrWindow;
    return null;
  }

  // Index of currently selected tab.
  get index() {
    return this._indexOf(this._current);
  }

  // Opens and returns a tab.  If an open window by the same name already exists,
  // opens this window in the same tab.  Omit name or use '_blank' to always open
  // a new tab.
  //
  // name    - Window name (optional)
  // opener  - Opening window (window.open call)
  // referer - Referrer
  // url     - Set document location to this URL upon opening
  // html    - Document contents (browser.load)
  open(options = {}) {

    // If name window in open tab, reuse that tab. Otherwise, open new window.
    const named = options.name && this.find(options.name.toString());
    if (named) {
      // Select this as the currenly open tab. Changing the location would then
      // select a different window.
      this._current = named;
      if (options.url)
        this._current.location = options.url;
      return this._current;
    }

    // When window changes we need to change tab slot. We can't keep the index
    // around, since tab order changes, so we look up the currently known
    // active window and switch that around.
    let active = null;
    const open = createHistory(this._browser, (window)=> {
      // Focus changes to different window, make it the active window
      if (!Tabs.sameWindow(window, active)) {
        const index = this._indexOf(active);
        if (index >= 0)
          this[index] = window;
        this.current = active = window;
      }
      if (window)
        this._browser._eventLoop.setActiveWindow(window);
    });

    const name = options.name === '_blank' ? '' : (options.name || '');
    options.name = name;
    const window = open(options);
    this.push(window);
    if (name && (this.propertyIsEnumerable(name) || !this[name]))
      this[name] = window;
    // Select this as the currenly open tab
    this.current = active = window;
    return window;
  }

  // Close an open tab.
  //
  // With no argument, closes the currently open tab (tabs.current).
  //
  // Argument can be the window, window name or tab position (same as find).
  close(nameOrWindow) {
    const window = nameOrWindow ?  this.find(nameOrWindow) : this._current;
    if (this._indexOf(window) >= 0)
      window.close();
  }

  // Closes all open tabs/windows.
  closeAll() {
    for (let tab of this.slice())
      tab.close();
  }

  // Dump list of all open tabs to stdout or output stream.
  dump(output = process.stdout) {
    if (this.length === 0) {
      output.write('No open tabs.\n');
      return;
    }
    for (let tab of this)
      output.write(`Window ${tab.name || 'unnamed'} open to ${tab.location.href}\n`);
  }


  // Find the position of this window in the tabs array
  _indexOf(window) {
    if (!window)
      return -1;
    return this.slice().map(tab => tab._globalProxy).indexOf(window._globalProxy);
  }

  // Called when window closed to remove it from tabs list.
  _closed(window) {
    const index = this._indexOf(window);
    if (index >= 0) {
      this._browser.emit('inactive', window);

      this.splice(index, 1);
      if (this.propertyIsEnumerable(window.name))
        delete this[window.name];

      // If we closed the currently open tab, need to select another window.
      if (Tabs.sameWindow(window, this._current)) {
        // Don't emit inactive event for closed window.
        this._current = this[index - 1] || this[0];
        if (this._current)
          this._browser.emit('active', this._current);
      }
    }

  }

  // Determine if two windows are the same
  static sameWindow(a, b) {
    return a && b && a._globalProxy === b._globalProxy;
  }
};

