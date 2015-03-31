// Tab management.

const _             = require('lodash');
const createHistory = require('./history');


module.exports = function createTabs(browser) {
  const tabs = [];
  let current = null;

  function indexOf(window) {
    if (!window)
      return -1;
    return tabs.map(tab => tab._id).indexOf(window._id);
  }

  function sameWindow(a, b) {
    return a && b && a._id === b._id;
  }

  Object.defineProperties(tabs, {

    // current property has a fancy setter
    current: {
      get() {
        return current;
      },
      set(indexOrWindow) {
        const window = tabs.find(indexOrWindow) || indexOrWindow;
        if (indexOf(window) < 0)
          return;
        if (!sameWindow(current, window)) {
          if (current)
            browser.emit('inactive', current);
          current = window;
          browser.emit('active', current);
        }
      }
    },

    // Dump list of all open tabs to stdout or output stream.
    dump: {
      value(output = process.stdout) {
        if (tabs.length === 0) {
          output.write('No open tabs.\n');
          return;
        }
        for (let tab of tabs)
          output.write(`Window ${tab.name || 'unnamed'} open to ${tab.location.href}\n`);
      }
    },

    // Opens and returns a tab.  If an open window by the same name already exists,
    // opens this window in the same tab.  Omit name or use '_blank' to always open
    // a new tab.
    //
    // name    - Window name (optional)
    // opener  - Opening window (window.open call)
    // referer - Referrer
    // url     - Set document location to this URL upon opening
    // html    - Document contents (browser.load)
    open: {
      value(options = {}) {
        let { name, url } = options;

        // When window changes we need to change tab slot. We can't keep the index
        // around, since tab order changes, so we look up the currently known
        // active window and switch that around.
        let active = null;

        // If name window in open tab, reuse that tab. Otherwise, open new window.
        const named = name && this.find(name.toString());
        if (named) {
          // Select this as the currenly open tab. Changing the location would then
          // select a different window.
          tabs.current = named;
          if (url)
            current.location = url;
          return current;
        } else {
          if (name === '_blank' || !name)
            name = '';

          const open = createHistory(browser, focus);
          options.url = url;
          const window = open(options);
          this.push(window);
          if (name && (this.propertyIsEnumerable(name) || !this[name]))
            this[name] = window;
          active = window;
          // Select this as the currenly open tab
          tabs.current = window;
          return window;
        }

        function focus(window) {
          if (!sameWindow(window, active)) {
            const index = indexOf(active);
            if (index >= 0)
              tabs[index] = window;
            tabs.current = window;
            active = window;
          }
          browser._eventLoop.setActiveWindow(window);
        }

      }
    },

    // Index of currently selected tab.
    index: {
      get() {
        return indexOf(current);
      }
    },

    // Returns window by index or name. Use this for window names that shadow
    // existing properties (e.g. tabs['open'] is a function, use
    find: {
      value(name) {
        if (tabs.propertyIsEnumerable(name))
          return tabs[name];
        return _.find(this, { name });
      }
    },

    // Close an open tab.  With no arguments, closes the currently open tab.  With
    // one argument, closes the tab for that window.  You can pass a window, window
    // name or index number.
    close: {
      value(window) {
        if (!window)
          window = current;
        else
          window = this.find(window) || window;
        if (indexOf(window) >= 0)
          window.close();
      }
    },

    // Closes all open tabs/windows.
    closeAll: {
      value() {
        for (let tab of this.slice(0))
          tab.close();
      }
    }

  });

  // We're notified when window is closed (by any means), and take that tab out
  // of circulation.
  browser.on('closed', function(window) {
    const index = indexOf(window);
    if (index >= 0) {
      browser.emit('inactive', window);

      tabs.splice(index, 1);
      if (tabs.propertyIsEnumerable(window.name))
        delete tabs[window.name];

      // If we closed the currently open tab, need to select another window.
      if (sameWindow(window, current)) {
        // Don't emit inactive event for closed window.
        if (index > 0)
          current = tabs[index - 1];
        else
          current = tabs[0];
        if (current)
          browser.emit('active', current);
      }
    }
  });

  return tabs;
};

