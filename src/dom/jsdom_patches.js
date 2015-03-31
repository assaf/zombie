// Fix things that JSDOM doesn't do quite right.


const DOM   = require('./index');
const Fetch = require('../fetch');
const Utils = require('jsdom/lib/jsdom/utils');
const URL   = require('url');


DOM.HTMLDocument.prototype.__defineGetter__('scripts', function() {
  return new DOM.HTMLCollection(this, ()=> this.querySelectorAll('script'));
});


// Default behavior for clicking on links: navigate to new URL if specified.
DOM.HTMLAnchorElement.prototype._eventDefaults =
  Object.assign({}, DOM.HTMLElement.prototype._eventDefaults);
DOM.HTMLAnchorElement.prototype._eventDefaults.click = function(event) {
  const anchor = event.target;
  if (!anchor.href)
    return;

  const window      = anchor.ownerDocument.defaultView;
  const { browser } = window;
  // Decide which window to open this link in
  switch (anchor.target || '_self') {
    case '_self': {   // navigate same window
      window.location = anchor.href;
      break;
    }
    case '_parent': { // navigate parent window
      window.parent.location = anchor.href;
      break;
    }
    case '_top': {    // navigate top window
      window.top.location = anchor.href;
      break;
    }
    default: { // open named window
      browser.tabs.open({ name: anchor.target, url: anchor.href });
      break;
    }
  }
  browser.emit('link', anchor.href, anchor.target || '_self');
};


// Attempt to load the image, this will trigger a 'load' event when succesful
// jsdom seemed to only queue the 'load' event
DOM.HTMLImageElement.prototype._attrModified = function(name, value, oldVal) {
  if (name === 'src' && value && value !== oldVal) {
    const src = DOM.resourceLoader.resolve(this._ownerDocument, value);
    if (this.src !== src)
      DOM.resourceLoader.load(this, value);
  }
};


// Implement insertAdjacentHTML
DOM.HTMLElement.prototype.insertAdjacentHTML = function(position, html) {
  const { parentNode }  = this;
  const container       = this.ownerDocument.createElementNS('http://www.w3.org/1999/xhtml', '_');
  container.innerHTML   = html;

  switch (position.toLowerCase()) {
    case 'beforebegin': {
      while (container.firstChild)
        parentNode.insertBefore(container.firstChild, this);
      break;
    }
    case 'afterbegin': {
      let firstChild = this.firstChild;
      while (container.lastChild)
        firstChild = this.insertBefore(container.lastChild, firstChild);
      break;
    }
    case 'beforeend': {
      while (container.firstChild)
        this.appendChild(container.firstChild);
      break;
    }
    case 'afterend': {
      let nextSibling = this.nextSibling;
      while (container.lastChild)
        nextSibling = parentNode.insertBefore(container.lastChild, nextSibling);
      break;
    }
  }
};


// Implement documentElement.contains
// e.g., if(document.body.contains(el)) { ... }
// See https://developer.mozilla.org/en-US/docs/DOM/Node.contains
DOM.Node.prototype.contains = function(otherNode) {
  // DDOPSON-2012-08-16 -- This implementation is stolen from Sizzle's
  // implementation of 'contains' (around line 1402).
  // We actually can't call Sizzle.contains directly:
  // * Because we define Node.contains, Sizzle will configure it's own
  //   "contains" method to call us. (it thinks we are a native browser
  //   implementation of "contains")
  // * Thus, if we called Sizzle.contains, it would form an infinite loop.
  //   Instead we use Sizzle's fallback implementation of "contains" based on
  //   "compareDocumentPosition".
  return !!(this.compareDocumentPosition(otherNode) & 16);
};


// Support for opacity style property.
Object.defineProperty(DOM.CSSStyleDeclaration.prototype, 'opacity', {
  get() {
    const opacity = this.getPropertyValue('opacity');
    return Number.isFinite(opacity) ? opacity.toString() : '';
  },

  set(opacity) {
    if (opacity === null || opacity === undefined || opacity === '')
      this.removeProperty('opacity');
    else {
      const value = parseFloat(opacity);
      if (isFinite(value))
        this._setProperty('opacity', value);
    }
  }
});


// Wrap dispatchEvent to support _windowInScope and error handling.
const jsdomDispatchEvent = DOM.EventTarget.prototype.dispatchEvent;
DOM.EventTarget.prototype.dispatchEvent = function(event) {
  // Could be node, window or document
  const document = this._ownerDocument || this.document || this;
  const window   = document.defaultView;
  // Fail miserably on objects that don't have ownerDocument: nodes and XHR
  // request have those
  const { browser } = window;
  browser.emit('event', event, this);

  const originalInScope = browser._windowInScope;
  try {
    // The current window, postMessage and window.close need this
    browser._windowInScope = window;
    // Inline event handlers rely on window.event
    window.event = event;
    return jsdomDispatchEvent.call(this, event);
  } finally {
    delete window.event;
    browser._windowInScope = originalInScope;
  }
};


// Wrap raise to catch and propagate all errors to window
const jsdomRaise = DOM.Document.prototype.raise;
DOM.Document.prototype.raise = function(type, message, data) {
  jsdomRaise.call(this, type, message, data);

  const error = data && (data.exception || data.error);
  if (!error)
    return;

  const document  = this;
  const window    = document.defaultView;
  // Deconstruct the stack trace and strip the Zombie part of it
  // (anything leading to this file).  Add the document location at
  // the end.
  const partial = [];
  // "RangeError: Maximum call stack size exceeded" doesn't have a stack trace
  if (error.stack)
    for (let line of error.stack.split('\n')) {
      if (~line.indexOf('contextify/lib/contextify.js'))
        break;
      partial.push(line);
    }
  partial.push(`    in ${document.location.href}`);
  error.stack = partial.join('\n');

  window._eventQueue.onerror(error);
};


// Fix resource loading to keep track of in-progress requests. Need this to wait
// for all resources (mainly JavaScript) to complete loading before terminating
// browser.wait.
DOM.resourceLoader.load = function(element, href, callback) {
  const document      = element.ownerDocument;
  const window        = document.defaultView;
  const tagName       = element.tagName.toLowerCase();
  const loadResource  = document.implementation._hasFeature('FetchExternalResources', tagName);
  const url           = DOM.resourceLoader.resolve(document, href);

  if (loadResource) {
    // This guarantees that all scripts are executed in order, must add to the
    // JSDOM queue before we add to the Zombie event queue.
    const enqueued = this.enqueue(element, callback && callback.bind(element), url);
    const request = new Fetch.Request(url);
    window._eventQueue.http(request, (error, response)=> {
      // Since this is used by resourceLoader that doesn't check the response,
      // we're responsible to turn anything other than 2xx/3xx into an error
      if (error)
        enqueued(new Error('Network error'));
      else if (response.status >= 400)
        enqueued(new Error(`Server returned status code ${response.status} from ${url}`));
      else
        response._consume().then((buffer)=> {
          response.body = buffer;
          enqueued(null, buffer);
        });
    });
  }
};

// Fix residual Node bug. See https://github.com/joyent/node/pull/14146
const jsdomResolveHref = Utils.resolveHref;
Utils.resolveHref = function (baseUrl, href) {
  const pattern = /file:?/;
  const protocol = URL.parse(baseUrl).protocol;
  const original = URL.parse(href);
  const resolved = URL.parse(jsdomResolveHref(baseUrl, href));

  if (!pattern.test(protocol) && pattern.test(original.protocol) && !original.host && resolved.host)
    return URL.format(original);
  else
    return URL.format(resolved);
};

