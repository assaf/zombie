// Fix things that JSDOM doesn't do quite right.


const DOM                  = require('./index');
const Fetch                = require('../fetch');
const resourceLoader       = require('jsdom/lib/jsdom/browser/resource-loader');
const Utils                = require('jsdom/lib/jsdom/utils');
const URL                  = require('url');
const {
  idlUtils,
  HTMLElementImpl,
  HTMLAnchorElementImpl,
  HTMLImageElementImpl
}                          = require('./impl');

HTMLAnchorElementImpl.implementation.prototype._activationBehavior = function(){
  const window      = this.ownerDocument.defaultView;
  const { browser } = window;
  const target = idlUtils.wrapperForImpl(this).target || '_self';

  // Decide which window to open this link in
  switch (target) {
    case '_self': {   // navigate same window
      window.location = this.href;
      break;
    }
    case '_parent': { // navigate parent window
      window.parent.location = this.href;
      break;
    }
    case '_top': {    // navigate top window
      window.top.location = this.href;
      break;
    }
    default: { // open named window
      browser.tabs.open({ name: target, url: this.href });
      break;
    }
  }
  browser.emit('link', this.href, target);
};


// Attempt to load the image, this will trigger a 'load' event when succesful
// jsdom seemed to only queue the 'load' event
// DOM.HTMLImageElement.prototype._attrModified = function(name, value, oldVal) {
HTMLImageElementImpl.implementation.prototype._attrModified = function(name, value, oldVal) {
  if (name === 'src' && value && value !== oldVal)
    resourceLoader.load(this, value);
  HTMLElementImpl.implementation.prototype._attrModified.call(this, name, value, oldVal);
};

// Implement getClientRects
DOM.HTMLElement.prototype.getClientRects = function () {
  const style = this.style;

  if (style && style.display === 'none') {
    return [];
  }

  return [{
    bottom: 0,
    height: 0,
    left: 0,
    right: 0,
    top: 0,
    width: 0
  }];
};

Object.defineProperty(DOM.HTMLElement.prototype, 'offsetHeight', {
  get: function () {
    return 0;
  }
});

Object.defineProperty(DOM.HTMLElement.prototype, 'offsetWidth', {
  get: function () {
    return 0;
  }
});


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
  const eventImpl = idlUtils.implForWrapper(this);
  const document = eventImpl._ownerDocument || this.document || this;

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


// Fix resource loading to keep track of in-progress requests. Need this to wait
// for all resources (mainly JavaScript) to complete loading before terminating
// browser.wait.
resourceLoader.load = function(element, href, encoding, callback) {
  const document      = element.ownerDocument;
  const window        = document.defaultView;
  const tagName       = element.tagName.toLowerCase();
  const loadResource  = document.implementation._hasFeature('FetchExternalResources', tagName);
  const url           = URL.resolve(document.URL, href);

  if (loadResource) {
    // This guarantees that all scripts are executed in order, must add to the
    // JSDOM queue before we add to the Zombie event queue.
    const enqueued = this.enqueue(element, url, callback && callback.bind(element));
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
