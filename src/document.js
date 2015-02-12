// Exports a function for creating/loading new documents.

const assert                  = require('assert');
const { browserAugmentation } = require('jsdom/lib/jsdom/browser');
const browserFeatures         = require('jsdom/lib/jsdom/browser/documentfeatures');
const Window                  = require('jsdom/lib/jsdom/browser/Window');
const DOM                     = require('./dom');
const EventSource             = require('eventsource');
const WebSocket               = require('ws');
const XMLHttpRequest          = require('./xhr');
const URL                     = require('url');


// Load/create a new document.
//
// Named arguments:
// browser   - The browser (required)
// history   - Window history (required)
// url       - URL of document to open (defaults to "about:blank")
// method    - HTTP method (defaults to "GET")
// encoding  - Request content type (forms use this)
// params    - Additional request parameters
// html      - Create document with this content instead of loading from URL
// name      - Window name
// referrer  - HTTP referer header
// parent    - Parent document (for frames)
// opener    - Opening window (for window.open)
// target    - Target window name (for form.submit)
//
// Returns a new document with a new window.  The document contents is loaded
// asynchronously, and will trigger a loaded/error event.
module.exports = function loadDocument(args) {
  const { browser, history } = args;
  assert(browser && browser.visit, 'Missing parameter browser');
  assert(history && history.reload, 'Missing parameter history');

  let { url } = args;
  if (url && browser.site) {
    const site  = /^(https?:|file:)/i.test(browser.site) ? browser.site : `http://${browser.site}`;
    url   = URL.resolve(site, URL.parse(URL.format(url)));
  }
  url     = url || 'about:blank';

  const document = createDocument(Object.assign({ url }, args));
  const window   = document.parentWindow;

  if (args.html) {
    window._eventQueue.enqueue(function() {
      document.write(args.html); // jshint ignore:line
      document.close();
      browser.emit('loaded', document);
    });
    return document;
  }

  // Let's handle the specifics of each protocol
  const { protocol, pathname } = URL.parse(url);
  switch (protocol) {
    case 'about:': {
      window._eventQueue.enqueue(function() {
        document.close();
        browser.emit('loaded', document);
      });
      break;
    }

    case 'javascript:': {
      window._eventQueue.enqueue(function() {
      document.close();
      try {
        window._evaluate(pathname, 'javascript:');
        browser.emit('loaded', document);
      } catch (error) {
        browser.emit('error', error);
      }
      });
      break;
    }

    default: {
      const method    = (args.method || 'GET').toUpperCase();
      // Proceeed to load resource ...
      const headers   = args.headers || {};
      // HTTP header Referer, but Document property referrer
      headers.referer = headers.referer || args.referrer || browser.referrer || browser.referer || history.url || '';
      // Tell the browser we're looking for an HTML document
      headers.accept  = headers.accept || 'text/html,*/*';
      // Forms require content type
      if (method === 'POST')
        headers['content-type'] = args.encoding || 'application/x-www-form-urlencoded';

      window._eventQueue.http(method, url, { headers, params: args.params, target: document }, (error, response)=> {
        if (response) {
          history.updateLocation(window, response.url);
          window._response    = response;
        }

        if (error) {
          // 4xx/5xx we get an error with an HTTP response
          // Error in body of page helps with debugging
          const message = (response && response.body) || error.message || error;
          document.write(`<html><body>${message}</body></html>`); //jshint ignore:line
          document.close();
        } else {
        
          document.write(response.body); //jshint ignore:line
          document.close();

          // Handle meta refresh.  Automatically reloads new location and counts
          // as a redirect.
          //
          // If you need to check the page before refresh takes place, use this:
          //   browser.wait({
          //     function: function() {
          //       return browser.query('meta[http-equiv="refresh"]');
          //     }
          //   });
          const refreshURL = getMetaRefreshURL(document);
          if (refreshURL) {
            // Allow completion function to run
            window._eventQueue.enqueue(function() {
              // Count a meta-refresh in the redirects count.
              history.replace(refreshURL || document.location.href);
              // This results in a new window getting loaded
              const newWindow = history.current.window;
              newWindow.addEventListener('load', function() {
                newWindow._response.redirects++;
              });
            });

          } else {

            if (document.documentElement)
              browser.emit('loaded', document);
            else
              browser.emit('error', new Error(`Could not parse document at ${response.url}`));
          }
        }
      });
      break;
    }
  }

  return document;
};


function getMetaRefreshURL(document) {
  const refresh = document.querySelector('meta[http-equiv="refresh"]');
  if (refresh) {
    const content = refresh.getAttribute('content');
    const match   = content.match(/^\s*(\d+)(?:\s*;\s*url\s*=\s*(.*?))?\s*(?:;|$)/i);
    if (match) {
      const refreshTimeout = parseInt(match[1], 10);
      const refreshURL     = match[2] || document.location.href;
      if (refreshTimeout >= 0)
        return refreshURL;
    }
  }
  return null;
}


// Creates an returns a new document attached to the window.
function createDocument(args) {
  const { browser } = args;

  const features = {
    FetchExternalResources:   [],
    ProcessExternalResources: [],
    MutationEvents:           '2.0'
  };
  if (browser.hasFeature('scripts', true)) {
    features.FetchExternalResources.push('script');
    features.ProcessExternalResources.push('script');
  }
  if (browser.hasFeature('css', false)) {
    features.FetchExternalResources.push('css');
    features.FetchExternalResources.push('link');
  }
  if (browser.hasFeature('img', false))
    features.FetchExternalResources.push('img');
  if (browser.hasFeature('iframe', true))
    features.FetchExternalResources.push('iframe');

  // Based on JSDOM.jsdom but skips the document.write
  // Calling document.write twice leads to strange results
  const dom       = browserAugmentation(DOM, { parsingMode: 'html' });
  const document  = new dom.HTMLDocument({ url: args.url, referrer: args.referrer, parsingMode: 'html' });
  browserFeatures.applyDocumentFeatures(document, features);
  const window    = document.parentWindow;
  setupDocument(document);
  setupWindow(window, args);

  // Give event handler chance to register listeners.
  browser.emit('loading', document);
  return document;
}


function setupDocument(document) {
  const window = document.parentWindow;
  Object.defineProperty(document, 'window', {
    value:      window,
    enumerable: true
  });
}


// File access, not implemented yet
class File {
}


// Screen object provides access to screen dimensions
class Screen {
  constructor() {
    this.top = this.left = 0;
    this.width = 1280;
    this.height = 800;
  }

  get availLeft() {
    return 0;
  }
  get availTop() {
    return 0;
  }
  get availWidth() {
    return 1280;
  }
  get availHeight() {
    return 800;
  }
  get colorDepth() {
    return 24;
  }
  get pixelDepth() {
    return 24;
  }
}


function setupWindow(window, args) {
  const { document }          = window;
  const global                = window.getGlobal();
  const { browser, history }  = args;
  const { parent, opener }    = args;

  let   closed        = false;

  // Access to browser
  Object.defineProperty(window, 'browser', {
    value:      browser,
    enumerable: true
  });

  window.name = args.name || '';

  // If this is an iframe within a parent window
  if (parent) {
    window.parent = parent;
    window.top    = parent.top;
  } else {
    window.parent = global;
    window.top    = global;
  }

  // If this was opened from another window
  window.opener   = opener;

  window.console = browser.console;

  // javaEnabled, present in browsers, not in spec Used by Google Analytics see
  /// https://developer.mozilla.org/en/DOM/window.navigator.javaEnabled
  const emptySet = [];
  emptySet.item = ()=> undefined;
  emptySet.namedItem = ()=> undefined;
  window.navigator = {
    appName:        'Zombie',
    cookieEnabled:  true,
    javaEnabled:    ()=> false,
    language:       browser.language,
    mimeTypes:      emptySet,
    noUI:           true,
    platform:       process.platform,
    plugins:        emptySet,
    userAgent:      browser.userAgent,
    vendor:         'Zombie Industries'
  };

  // Add cookies, storage, alerts/confirm, XHR, WebSockets, JSON, Screen, etc
  Object.defineProperty(window, 'cookies', {
    get() {
      return browser.cookies.serialize(this.location.hostname, this.location.pathname);
    }
  });
  browser._storages.extend(window);
  browser._interact.extend(window);

  window.File =           File;
  window.Event =          DOM.Event;
  window.MouseEvent =     DOM.MouseEvent;
  window.MutationEvent =  DOM.MutationEvent;
  window.UIEvent =        DOM.UIEvent;
  window.screen =         new Screen();

  // Base-64 encoding/decoding
  window.atob = (string)=> new Buffer(string, 'base64').toString('utf8');
  window.btoa = (string)=> new Buffer(string, 'utf8').toString('base64');

  // Constructor for XHLHttpRequest
  window.XMLHttpRequest = ()=> new XMLHttpRequest(window);

  // Web sockets
  window.WebSocket = function(url, protocol) {
    url = DOM.resourceLoader.resolve(document, url);
    const origin = `${window.location.protocol}//${window.location.host}`;
    return new WebSocket(url, { origin, protocol });
  };

  window.Image = function(width, height) {
    const img   = new DOM.HTMLImageElement(window.document);
    img.width   = width;
    img.height  = height;
    return img;
  };

  // DataView: get from globals
  window.DataView = DataView;

  window.resizeTo = function(width, height) {
    window.outerWidth   = window.innerWidth   = width;
    window.outerHeight  = window.innerHeight  = height;
  };
  window.resizeBy = function(width, height) {
    window.resizeTo(window.outerWidth + width,  window.outerHeight + height);
  };

  // Some libraries (e.g. Backbone) check that this property exists before
  // deciding to use onhashchange, so we need to set it to null.
  window.onhashchange = null;



  // -- JavaScript evaluation

  // Evaulate in context of window. This can be called with a script (String) or a function.
  window._evaluate = function(code, filename) {
    const originalInScope = browser._windowInScope;
    try {
      // The current window, postMessage and window.close need this
      browser._windowInScope = window;
      let result;
      if (typeof(code) === 'string' || code instanceof String) {
        result = global.run(code, filename);
      } else if (code) {
        result = code.call(global);
      }
      browser.emit('evaluated', code, result, filename);
      return result;
    } catch (error) {
      error.filename = error.filename || filename;
      throw error;
    } finally {
      browser._windowInScope = originalInScope;
    }
  };


  // -- Event loop --

  const eventQueue = browser.eventLoop.createEventQueue(window);
  Object.defineProperty(window, '_eventQueue', {
    value: eventQueue
  });
  window.setTimeout     = eventQueue.setTimeout.bind(eventQueue);
  window.clearTimeout   = eventQueue.clearTimeout.bind(eventQueue);
  window.setInterval    = eventQueue.setInterval.bind(eventQueue);
  window.clearInterval  = eventQueue.clearInterval.bind(eventQueue);
  window.setImmediate   = (fn)=> eventQueue.setTimeout(fn, 0);
  window.clearImmediate = eventQueue.clearTimeout.bind(eventQueue);
  window.requestAnimationFrame  = window.setImmediate;


  // Constructor for EventSource, URL is relative to document's.
  window.EventSource = function(url) {
    url = DOM.resourceLoader.resolve(document, url);
    const eventSource = new EventSource(url);
    eventQueue.addEventSource(eventSource);
    return eventSource;
  };


  // -- Opening and closing --

  // Open one window from another.
  window.open = function(url, name, features) { // jshint unused:false
    url = url && DOM.resourceLoader.resolve(document, url);
    return browser.tabs.open({ name: name, url: url, opener: window });
  };

  // Indicates if window was closed
  Object.defineProperty(window, 'closed', {
    get() { return closed; },
    enumerable: true
  });

  // Destroy all the history (and all its windows), frames, and Contextify
  // global.
  window._destroy = function() {
    // We call history.destroy which calls destroy on all windows, so need to
    // avoid infinite loop.
    if (closed)
      return;

    closed = true;
    // Close all frames first
    for (let i = 0; i < window.length; ++i)
      window[i].close();
    // kill event queue, document and window.
    eventQueue.destroy();
    document.close();
    window.dispose();
  };

  // window.close actually closes the tab, and disposes of all windows in the history.
  // Also used to close iframe.
  window.close = function() {
    if (parent || closed)
      return;
    // Only opener window can close window; any code that's not running from
    // within a window's context can also close window.
    if (browser._windowInScope === opener || browser._windowInScope === null) {
      // Only parent window gets the close event
      browser.emit('closed', window);
      window._destroy();
      history.destroy(); // do this last to prevent infinite loop
    } else
      browser.log('Scripts may not close windows that were not opened by script');
  };


  // -- Navigating --

  // Each window maintains its own view of history
  const windowHistory = {
    forward() {
      windowHistory.go(1);
    },
    back() {
      windowHistory.go(-1);
    },
    go(amount) {
      browser.eventLoop.next(function() {
        history.go(amount);
      });
    },
    pushState(...args) {
      history.pushState(...args);
    },
    replaceState(...args) {
      history.replaceState(...args);
    }
  };
  Object.defineProperties(windowHistory, {
    length: {
      get() { return history.length; },
      enumerable: true
    },
    state: {
      get() { return history.state; },
      enumerable: true
    }
  });

  // DOM History object
  window.history  = windowHistory;
  /// Actual history, see location getter/setter
  window._history = history;


  // Form submission uses this
  window._submit = function(args) {
    const url     = DOM.resourceLoader.resolve(document, args.url);
    const target  = args.target || '_self';
    browser.emit('submit', url, target);
    // Figure out which history is going to handle this
    const targetWindow =
      (target === '_self')   ? window :
      (target === '_parent') ? window.parent :
      (target === '_top')    ? window.top :
      browser.tabs.open({ name: target });
    const modified = Object.assign({}, args, { url, target });
    targetWindow._history.submit(modified);
  };

  // JSDOM fires DCL event on document but not on window
  function windowLoaded(event) {
    document.removeEventListener('DOMContentLoaded', windowLoaded);
    window.dispatchEvent(event);
  }
  document.addEventListener('DOMContentLoaded', windowLoaded);
  
  // Window is now open, next load the document.
  browser.emit('opened', window);
}




// Change location, bypass JSDOM history
Window.prototype.__defineSetter__('location', function(url) {
  return this._history.assign(url);
});

// Change location
DOM.Document.prototype.__defineSetter__('location', function(url) {
  this.parentWindow.location = url;
});


// Help iframes talking with each other
Window.prototype.postMessage = function(data, targetOrigin) { // jshint unused:false
  // Create the event now, but dispatch asynchronously
  const event = this.document.createEvent('MessageEvent');
  event.initEvent('message', false, false);
  event.data = data;
  // Window A (source) calls B.postMessage, to determine A we need the
  // caller's window.

  // DDOPSON-2012-11-09 - _windowInScope.getGlobal() is used here so that for
  // website code executing inside the sandbox context, event.source ==
  // window. Even though the _windowInScope object is mapped to the sandboxed
  // version of the object returned by getGlobal, they are not the same object
  // ie, _windowInScope.foo == _windowInScope.getGlobal().foo, but
  // _windowInScope != _windowInScope.getGlobal()
  event.source = (this.browser._windowInScope || this).getGlobal();
  const origin = event.source.location;
  event.origin = URL.format({ protocol: origin.protocol, host: origin.host });
  this.dispatchEvent(event);
};

