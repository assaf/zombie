// Exports a function for creating/loading new documents.

const assert          = require('assert');
const browserFeatures = require('jsdom/lib/jsdom/browser/documentfeatures');
const Fetch           = require('./fetch');
const DOM             = require('./dom');
const EventSource     = require('eventsource');
const iconv           = require('iconv-lite');
const QS              = require('querystring');
const Resources       = require('./resources');
const URL             = require('url');
const Utils           = require('jsdom/lib/jsdom/utils');
const VM              = require('vm');
const WebSocket       = require('ws');
const Window          = require('jsdom/lib/jsdom/browser/Window');
const XMLHttpRequest  = require('./xhr');


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


// DOM implementation of URL class
class DOMURL {

  constructor(url, base) {
    if (url == null)
       throw new TypeError('Failed to construct \'URL\': Invalid URL');
    if (base)
      url = Utils.resolveHref(base, url);
    const parsed = URL.parse(url || 'about:blank');
    const origin = parsed.protocol && parsed.hostname && `${parsed.protocol}//${parsed.hostname}`;
    Object.defineProperties(this, {
      hash:     { value: parsed.hash,         enumerable: true },
      host:     { value: parsed.host,         enumerable: true },
      hostname: { value: parsed.hostname,     enumerable: true },
      href:     { value: URL.format(parsed),  enumerable: true },
      origin:   { value: origin,              enumerable: true },
      password: { value: parsed.password,     enumerable: true },
      pathname: { value: parsed.pathname,     enumerable: true },
      port:     { value: parsed.port,         enumerable: true },
      protocol: { value: parsed.protocol,     enumerable: true  },
      search:   { value: parsed.search,       enumerable: true },
      username: { value: parsed.username,     enumerable: true }
    });
  }

  toString() {
    return this.href;
  }

}


function setupWindow(window, args) {
  const { document }          = window;
  const { browser, history }  = args;
  const { parent, opener }    = args;

  let   closed        = false;

  // Access to browser
  Object.defineProperty(window, 'browser', {
    value:      browser,
    enumerable: true
  });

  window.name     = args.name || '';

  // If this was opened from another window
  window.opener   = opener && opener._globalProxy;
  // Frames provide their own parent reference
  window._parent  = (parent || window);
  window._top     = (parent || window).top;

  window.console = browser.console;

  // All the resources loaded by this window.
  window.resources = new Resources(window);

  // javaEnabled, present in browsers, not in spec Used by Google Analytics see
  /// https://developer.mozilla.org/en/DOM/window.navigator.javaEnabled
  const emptySet = [];
  emptySet.item = ()=> undefined;
  emptySet.namedItem = ()=> undefined;
  window.navigator = {
    appName:        'Zombie',
    appVersion:     browser.constructor.VERSION,
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

  window.File =           File;
  window.Event =          DOM.Event;
  window.MouseEvent =     DOM.MouseEvent;
  window.MutationEvent =  DOM.MutationEvent;
  window.UIEvent =        DOM.UIEvent;
  window.screen =         new Screen();

  // Fetch API
  window.fetch =          window.resources._fetch.bind(window.resources);
  window.Request =        Fetch.Request;
  window.Response =       Fetch.Response;
  window.FormData =       Fetch.FormData;

  // Base-64 encoding/decoding
  window.atob = (string)=> new Buffer(string, 'base64').toString('utf8');
  window.btoa = (string)=> new Buffer(string, 'utf8').toString('base64');

  // Constructor for XHLHttpRequest
  window.XMLHttpRequest = ()=> new XMLHttpRequest(window);
  window.URL = DOMURL;

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
      if (typeof code === 'string' || code instanceof String)
        result = VM.runInContext(code, window, { filename });
      else if (code)
        result = code.call(window);
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

  const eventQueue = browser._eventLoop.createEventQueue(window);
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


  // -- Interaction --

  window.alert = function(message) {
    const handled = browser.emit('alert', message);
    if (!handled)
      browser.log('Unhandled window.alert("%s")');
    browser.log('alert("%s")', message);
  };

  window.confirm = function(question) {
    const event     = { question, response: true };
    const handled   = browser.emit('confirm', event);
    if (!handled)
      browser.log('Unhandled window.confirm("%s")');
    const response  = !!event.response;
    browser.log('confirm("%s") -> %ss', question, response);
    return response;
  };

  window.prompt = function(question, value) {
    const event     = { question, response: value || '' };
    const handled   = browser.emit('prompt', event);
    if (!handled)
      browser.log('Unhandled window.prompt("%s")');
    const response  = (event.response || '').toString();
    browser.log('prompt("..") -> "%s"', question, response);
    return response;
  };


  // -- Opening and closing --

  // Open one window from another.
  window.open = function(url, name) {
    url = url && DOM.resourceLoader.resolve(document, url);
    return browser.tabs.open({ name: name, url: url, opener: window });
  };

  // Indicates if window was closed
  Object.defineProperty(window, 'closed', {
    get() { return closed; },
    enumerable: true
  });

  // Used by window.close() and also from history.destroy/replace/etc
  // global.
  window._destroy = function() {
    // We call history.destroy which calls destroy on all windows, so need to
    // avoid infinite loop.
    if (closed)
      return;
    closed = true;

    // Close all frames first
    for (let i = 0; i < window._length; ++i)
      if (window[i])
        window[i].close();
    // kill event queue, document and window.
    eventQueue.destroy();
    document.close();
  };

  // window.close actually closes the tab, and disposes of all windows in the history.
  // Also used to close iframe.
  window.close = function() {
    if (parent || closed)
      return;

    // Only opener window can close window; any code that's not running from
    // within a window's context can also close window.
    if (browser._windowInScope === opener || browser._windowInScope === null) {
      browser.tabs._closed(window);
      // Only parent window gets the close event
      browser.emit('closed', window);
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
      history.go(amount);
    },
    pushState(...stateArgs) {
      history.pushState(...stateArgs);
    },
    replaceState(...stateArgs) {
      history.replaceState(...stateArgs);
    },
    dump(output) {
      history.dump(output);
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

  // Read/write access to window.location
  Object.defineProperty(window, 'location', {
    get() {
      return document.location;
    },
    set(url) {
      history.assign(url);
    }
  });


  // Form submission uses this
  window._submit = function(formArgs) {
    const url     = DOM.resourceLoader.resolve(document, formArgs.url);
    const target  = formArgs.target || '_self';
    browser.emit('submit', url, target);
    // Figure out which history is going to handle this
    const targetWindow =
      (target === '_self')   ? window :
      (target === '_parent') ? window.parent :
      (target === '_top')    ? window.top :
      browser.tabs.open({ name: target });
    const modified = Object.assign({}, formArgs, { url, target });
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


// Help iframes talking with each other
Window.prototype.postMessage = function(data) {
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
  event.source = (this.browser._windowInScope || this);
  const origin = event.source.location;
  event.origin = URL.format({ protocol: origin.protocol, host: origin.host });
  this.dispatchEvent(event);
};


// Change location
DOM.Document.prototype.__defineSetter__('location', function(url) {
  this.defaultView.location = url;
});


// Creates an returns a new document attached to the window.
function createDocument(args) {
  const { browser } = args;

  const features = {
    FetchExternalResources:   [],
    ProcessExternalResources: [],
    MutationEvents:           '2.0'
  };
  if (args.browser.hasFeature('scripts', true)) {
    features.FetchExternalResources.push('script');
    features.ProcessExternalResources.push('script');
  }
  if (args.browser.hasFeature('css', false)) {
    features.FetchExternalResources.push('css');
    features.FetchExternalResources.push('link');
  }
  if (args.browser.hasFeature('img', false))
    features.FetchExternalResources.push('img');
  if (args.browser.hasFeature('iframe', true))
    features.FetchExternalResources.push('iframe');

  const window  = new Window({
    parsingMode:  'html',
    contentType:  'text/html',
    url:          args.url,
    referrer:     args.referrer
  });
  const { document } = window;
  browserFeatures.applyDocumentFeatures(document, features);
  setupWindow(window, args);

  // Give event handler chance to register listeners.
  args.browser.emit('loading', document);
  return document;
}


// Get refresh URL from <meta> tag
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


// Find the charset= value of the meta tag
const MATCH_CHARSET = /<meta(?!\s*(?:name|value)\s*=)[^>]*?charset\s*=[\s"']*([^\s"'\/>]*)/i;

// Extract HTML from response with the proper encoding:
// - If content type header indicates charset use that
// - Otherwise, look for <meta> tag with charset in body
// - Otherwise, browsers default to windows-1252 encoding
function getHTMLFromResponseBody(buffer, contentType) {
  const [mimeType, ...typeOptions]  = contentType.split(/;\s*/);

  // Pick charset from content type
  if (mimeType)
    for (let typeOption of typeOptions) {
      if (/^charset=/i.test(typeOption)) {
        const charset = typeOption.split('=')[1];
        return iconv.decode(buffer, charset);
      }
    }

  // Otherwise, HTML documents only, pick charset from meta tag
  // Otherwise, HTML documents only, default charset in US is windows-1252
  const charsetInMetaTag = buffer.toString().match(MATCH_CHARSET);
  if (charsetInMetaTag)
    return iconv.decode(buffer, charsetInMetaTag[1]);
  else
    return iconv.decode(buffer, 'windows-1252');
}


// Builds and returns a new Request, adding form parameters to URL (GET) or
// request body (POST).
function buildRequest(args) {
  const { browser, method, params } = args;
  const site  = /^(https?:|file:)/i.test(browser.site) ? browser.site : `http://${browser.site || 'locahost'}`;
  const url   = Utils.resolveHref(site, URL.format(args.url));

  const headers = new Fetch.Headers(args.headers);

  // HTTP header Referer, but Document property referrer
  const referrer = args.referrer || browser.referrer || browser.referer || args.history.url;
  if (referrer && !headers.has('Referer'))
    headers.set('Referer', referrer);
  if (!headers.has('Accept'))
    headers.set('Accept', 'text/html,*/*');

  if (/^GET|HEAD|DELETE$/i.test(method)) {
    const uri = URL.parse(url, true);
    if (params)
      // These methods use query string parameters instead
      Object.assign(uri.query, params);
    return new Fetch.Request(URL.format(uri), { method, headers });
  }

  const mimeType = (args.encoding || '').split(';')[0];
  // Default mime type, but can also be specified in form encoding
  if (mimeType === '' || mimeType === 'application/x-www-form-urlencoded') {
    const urlEncoded = QS.stringify(params || {});
    headers.set('Content-Type', 'application/x-www-form-urlencoded;charset=UTF-8');
    return new Fetch.Request(url, { method, headers, body: urlEncoded });
  }

  if (mimeType === 'multipart/form-data') {
    const form = new Fetch.FormData();
    if (params)
      Object.keys(params).forEach((name)=> {
        params[name].forEach((value)=> {
          form.append(name, value);
        });
      });
    return new Fetch.Request(url, { method, headers, body: form });
  }

  throw new TypeError(`Unsupported content type ${mimeType}`);
}


// Parse HTML response and setup document
async function parseResponse({ browser, history, document, response }) {
  const window = document.defaultView;
  const done   = window._eventQueue.waitForCompletion();

  try {
    window._request   = response.request;
    window._response  = response;
    history.updateLocation(window, response._url);

    const buffer      = await response._consume();
    const contentType = response.headers.get('Content-Type') || '';
    const html        = getHTMLFromResponseBody(buffer, contentType);
    response.body     = html;
    document.write(html);
    document.close();

    if (response.status >= 400)
      throw new Error(`Server returned status code ${response.status} from ${response.url}`);
    if (!document.documentElement)
      throw new Error(`Could not parse document at ${response.url}`);
    browser.emit('loaded', document);

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
    if (refreshURL)
      // Allow completion function to run
      window._eventQueue.enqueue(function() {
        window._eventQueue.enqueue(function() {
          // Count a meta-refresh in the redirects count.
          history.replace(refreshURL || document.location.href);
          // This results in a new window getting loaded
          const newWindow = history.current.window;
          newWindow.addEventListener('load', function() {
            ++newWindow._request._redirectCount;
          });
        });
      });

  } catch (error) {
    browser.emit('error', error);
  } finally {
    done();
  }
}


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
  const { browser, history, html, url } = args;
  assert(browser && browser.visit, 'Missing parameter browser');
  assert(history && history.reload, 'Missing parameter history');

  const document = createDocument(Object.assign({ url }, args));
  const window   = document.defaultView;

  if (html) {
    window._eventQueue.enqueue(function() {
      document.write(html);
      document.close();
      browser.emit('loaded', document);
    });
    return document;
  }

  // Let's handle the specifics of each protocol
  if (!url || url.startsWith('about:')) {
    window._eventQueue.enqueue(function() {
      document.close();
      browser.emit('loaded', document);
    });
    return document;
  }

  if (url.startsWith('javascript:')) {
    window._eventQueue.enqueue(function() {
      document.close();
      try {
        window._evaluate(url.slice(11), 'javascript:');
        browser.emit('loaded', document);
      } catch (error) {
        browser.emit('error', error);
      }
    });
    return document;
  }

  const request = buildRequest(args);
  window._eventQueue.http(request, async (error, response)=> {
    if (error) {
      document.write(`<html><body>${error.message}</body></html>`);
      document.close();
      browser.emit('error', error);
    } else
      parseResponse({ browser, history, document, response });

  });
  return document;
};


