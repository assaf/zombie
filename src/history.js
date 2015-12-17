// Window history.
//
// Each window belongs to a history. Think of history as a timeline, with
// currently active window, and multiple previous and future windows. From that
// window you can navigate backwards and forwards between all other windows that
// belong to the same history.
//
// Each window also has a container: either a browser tab or an iframe. When
// navigating in history, a different window (from the same history), replaces
// the current window within its container.
//
// Containers have access to the currently active window, not the history
// itself, so navigation has to alert the container when there's a change in the
// currently active window.
//
// The history does so by calling a "focus" function. To create the first
// window, the container must first create a new history and supply a focus
// function. The result is another function it can use to create the new window.
//
// From there on, it can navigate in history and add new windows by changing the
// current location (or using assign/replace).
//
// It can be used like this:
//
//   active = null
//   focus = (window)->
//     active = window
//   history = createHistory(browser, focus)
//   window = history(url: url, name: name)


const assert          = require('assert');
const loadDocument    = require('./document');
const resourceLoader  = require('jsdom/lib/jsdom/browser/resource-loader');
const URL             = require('url');


class Location {

  constructor(history, url) {
    this._history = history;
    this._url = url || (history.current ? history.current.url : 'about:blank');
  }

  assign(url) {
    this._history.assign(url);
  }

  replace(url) {
    this._history.replace(url);
  }

  reload() {
    this._history.reload();
  }

  toString() {
    return this._url;
  }

  get hostname() {
    return URL.parse(this._url).hostname;
  }

  set hostname(hostname) {
    const newUrl = URL.parse(this._url);
    if (newUrl.port)
      newUrl.host = `${hostname}:${newUrl.port}`;
    else
      newUrl.host = hostname;
    this.assign(URL.format(newUrl));
  }

  get href() {
    return this._url;
  }

  set href(href) {
    this.assign(URL.format(href));
  }

  get origin() {
    return `${this.protocol}//${this.host}`;
  }

  get hash() {
    return URL.parse(this._url).hash || '';
  }

  set hash(value) {
    const url  = Object.assign(URL.parse(this._url), { hash: value });
    this.assign(URL.format(url));
  }

  get host() {
    return URL.parse(this._url).host || '';
  }

  set host(value) {
    const url  = Object.assign(URL.parse(this._url), { host: value });
    this.assign(URL.format(url));
  }

  get pathname() {
    return URL.parse(this._url).pathname || '';
  }

  set pathname(value) {
    const url  = Object.assign(URL.parse(this._url), { pathname: value });
    this.assign(URL.format(url));
  }

  get port() {
    return URL.parse(this._url).port || '';
  }

  set port(value) {
    const url  = Object.assign(URL.parse(this._url), { port: value });
    this.assign(URL.format(url));
  }

  get protocol() {
    return URL.parse(this._url).protocol || '';
  }

  set protocol(value) {
    const url  = Object.assign(URL.parse(this._url), { protocol: value });
    this.assign(URL.format(url));
  }

  get search() {
    return URL.parse(this._url).search || '';
  }

  set search(value) {
    const url  = Object.assign(URL.parse(this._url), { search: value });
    this.assign(URL.format(url));
  }
}


// Returns true if the hash portion of the URL changed between the history entry
// (entry) and the new URL we want to inspect (url).
function hashChange(entry, url) {
  if (!entry)
    return false;
  const [aBase, aHash] = url.split('#');
  const [bBase, bHash] = entry.url.split('#');
  return (aBase === bBase) && (aHash !== bHash);
}

// If window is not the top level window, return parent for creating new child
// window, otherwise returns false.
function parentFrom(window) {
  if (window.parent !== window)
    return window.parent;
}


// Entry has the following properties:
// window      - Window for this history entry (may be shared with other entries)
// url         - URL for this history entry
// pushState   - Push state state
// next        - Next entry in history
// prev        - Previous entry in history
class Entry {

  constructor(window, url, pushState) {
    this.window     = window;
    this.url        = URL.format(url);
    this.pushState  = pushState;
    this.prev       = null;
    this.next       = null;
  }

  // Called to destroy this entry. Used when we destroy the entire history,
  // closing all windows. But also used when we replace one entry with another,
  // and there are two cases to worry about:
  // - The current entry uses the same window as the previous entry, we get rid
  //   of the entry, but must keep the entry intact
  // - The current entry uses the same window as the new entry, also need to
  //   keep window intact
  //
  // keepAlive - Call destroy on every document except this one, since it's
  //             being replaced.
  destroy(keepAlive) {
    if (this.next) {
      this.next.destroy(keepAlive || this.window);
      this.next = null;
    }
    // Do not close window if replacing entry with same window
    if (keepAlive === this.window)
      return;
    // Do not close window if used by previous entry in history
    if (this.prev && this.prev.window === this.window)
      return;
    this.window._destroy();
  }

  append(newEntry, keepAlive) {
    if (this.next)
      this.next.destroy(keepAlive);
    newEntry.prev = this;
    this.next = newEntry;
  }

}


class History {

  constructor(browser, focus) {
    this.browser  = browser;
    this.focus    = focus;
    this.first    = null;
    this.current  = null;
  }

  // Opens the first window and returns it.
  open(args) {
    args.browser = this.browser;
    args.history = this;
    const document  = loadDocument(args);
    const window    = document.defaultView;
    this.addEntry(window, args.url);
    return window;
  }

  // Dispose of all windows in history
  destroy() {
    this.focus(null);
    // Re-entrant
    const first   = this.first;
    this.first    = null;
    this.current  = null;
    if (first)
      first.destroy();
  }

  // Add a new entry.  When a window opens it call this to add itself to history.
  addEntry(window, url = window.location.href, pushState = undefined) {
    const entry = new Entry(window, url, pushState);
    if (this.current) {
      this.current.append(entry);
      this.current  = entry;
    } else {
      this.first    = entry;
      this.current  = entry;
    }
    this.focus(window);
  }

  // Replace current entry with a new one.
  replaceEntry(window, url = window.location.href, pushState = undefined) {
    const entry = new Entry(window, url, pushState);
    if (this.current === this.first) {
      if (this.current)
        this.current.destroy(window);
      this.first    = entry;
      this.current  = entry;
    } else {
      this.current.prev.append(entry, window);
      this.current  = entry;
    }
    this.focus(window);
  }

  // Call with two argument to update window.location and current.url to new URL
  updateLocation(window, url) {
    if (window === this.current)
      this.current.url = url;
    window.document._URL       = url;
    window.document._location  = new Location(this, url);
  }

  // Returns window.location
  get location() {
    return new Location(this);
  }


  // Form submission
  submit(args) {
    args.browser   = this.browser;
    args.history   = this;
    const { window }  = this.current;
    if (window) {
      args.name      = window.name;
      args.parent    = parentFrom(window);
      args.referrer  = window.location.href;
      args.opener    = window.opener || null;
    }
    const document  = loadDocument(args);
    this.addEntry(document.defaultView, document.location.href);
  }

  // Returns current URL.
  get url() {
    return this.current && this.current.url;
  }


  // -- Implementation of window.history --

  // This method is available from Location, used to navigate to a new page.
  assign(url) {
    let name = '';
    let parent = null;
    let opener = null;

    if (this.current) {
      url     = resourceLoader.resolveResourceUrl(this.current.window.document, url);
      name    = this.current.window.name;
      parent  = parentFrom(this.current.window);
      opener  = this.current.window.opener || null;
    }
    if (this.current && this.current.url === url) {
      this.replace(url);
      return;
    }

    if (hashChange(this.current, url)) {
      const { window } = this.current;
      this.updateLocation(window, url);
      this.addEntry(window, url); // Reuse window with new URL
      const event = window.document.createEvent('HTMLEvents');
      event.initEvent('hashchange', true, false);
      window._eventQueue.enqueue(function() {
        window.dispatchEvent(event);
      });
    } else {
      const args = {
        browser:  this.browser,
        history:  this,
        name:     name,
        url:      url,
        parent:   parent,
        opener:   opener,
        referrer: this.current && this.current.window.document.referrer
      };
      const document = loadDocument(args);
      this.addEntry(document.defaultView, url);
    }
  }

  // This method is available from Location, used to navigate to a new page.
  replace(url) {
    url = URL.format(url);
    let name = '';
    let parent = null;
    let opener = null;

    if (this.current) {
      url     = resourceLoader.resolveResourceUrl(this.current.window.document, url);
      name    = this.current.window.name;
      parent  = parentFrom(this.current.window);
      opener  = this.current.window.opener || null;
    }

    if (hashChange(this.current, url)) {
      const { window } = this.current;
      this.replaceEntry(window, url); // Reuse window with new URL
      const event = window.document.createEvent('HTMLEvents');
      event.initEvent('hashchange', true, false);
      window._eventQueue.enqueue(function() {
        window.dispatchEvent(event);
      });
    } else {
      const args = {
        browser:  this.browser,
        history:  this,
        name:     name,
        url:      url,
        parent:   parent,
        opener:   opener
      };
      const document = loadDocument(args);
      this.replaceEntry(document.defaultView, url);
    }
  }

  reload() {
    const { window } = this.current;
    if (window) {
      const url   = window.location.href;
      const args  = {
        browser:  this.browser,
        history:  this,
        name:     window.name,
        url:      url,
        parent:   parentFrom(window),
        referrer: window.document.referrer,
        opener:   window.opener || null
      };
      const document = loadDocument(args);
      this.replaceEntry(document.defaultView, url);
    }
  }

  // This method is available from Location.
  go(amount) {
    const was = this.current;
    while (amount > 0) {
      if (this.current.next)
        this.current = this.current.next;
      --amount;
    }
    while (amount < 0) {
      if (this.current.prev)
        this.current = this.current.prev;
      ++amount;
    }

    // If moving from one page to another
    if (this.current && was && this.current !== was) {
      const { window } = this.current;
      this.updateLocation(window, this.current.url);
      this.focus(window);

      if (this.current.pushState || was.pushState) {
        // Created with pushState/replaceState, send popstate event if navigating
        // within same host.
        const oldHost = URL.parse(was.url).host;
        const newHost = URL.parse(this.current.url).host;
        if (oldHost === newHost) {
          const popstate = window.document.createEvent('HTMLEvents');
          popstate.initEvent('popstate', false, false);
          popstate.state = this.current.pushState;
          window._eventQueue.enqueue(function() {
            window.dispatchEvent(popstate);
          });
        }
      } else if (hashChange(was, this.current.url)) {
        const hashchange = window.document.createEvent('HTMLEvents');
        hashchange.initEvent('hashchange', true, false);
        window._eventQueue.enqueue(function() {
          window.dispatchEvent(hashchange);
        });
      }
    }
  }


  // This method is available from Location.
  get length() {
    let entry = this.first;
    let length = 0;
    while (entry) {
      ++length;
      entry = entry.next;
    }
    return length;
  }


  // This method is available from Location.
  pushState(state, title, url = this.url) {
    url = resourceLoader.resolveResourceUrl(this.current.window.document, url);
    // TODO: check same origin
    this.addEntry(this.current.window, url, state || {});
    this.updateLocation(this.current.window, url);
  }

  // This method is available from Location.
  replaceState(state, title, url = this.url) {
    url = resourceLoader.resolveResourceUrl(this.current.window.document, url);
    // TODO: check same origin
    this.replaceEntry(this.current.window, url, state || {});
    this.updateLocation(this.current.window, url);
  }

  // This method is available from Location.
  get state() {
    return this.current.pushState;
  }


  dump(output = process.stdout) {
    for (let entry = this.first, i = 1; entry; entry = entry.next, ++i)
      output.write(`${i}: ${URL.format(entry.url)}\n`);
  }
}


// Creates and returns a new history.
//
// browser - The browser object
// focus   - The focus method, called when a new window is in focus
//
// Returns a function for opening a new window, which accepts:
// name      - Window name (optional)
// opener    - Opening window (window.open call)
// parent    - Parent window (for frames)
// url       - Set document location to this URL upon opening
module.exports = function createHistory(browser, focus) {
  assert(browser && browser.visit, 'Missing parameter browser');
  assert(focus && focus.call, 'Missing parameter focus or not a function');
  const history = new History(browser, focus);
  return history.open.bind(history);
};

