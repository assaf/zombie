// Support for iframes.


const DOM = require('./index');


// Support for iframes that load content when you set the src attribute.
const frameInit = DOM.HTMLFrameElement._init;
DOM.HTMLFrameElement._init = function() {
  frameInit.call(this);
  this.removeEventListener('DOMNodeInsertedIntoDocument', this._initInsertListener);

  const iframe        = this;
  const parentWindow  = iframe.ownerDocument.parentWindow;
  var contentWindow   = null;

  Object.defineProperties(iframe, {
    contentWindow: {
      get() {
        return contentWindow || createWindow();
      }
    },
    contentDocument: {
      get() {
        return (contentWindow || createWindow()).document;
      }
    }
  });


  // URL created on the fly, or when src attribute set
  function createWindow() {
    const createHistory = require('../history');
    // Need to bypass JSDOM's window/document creation and use ours
    const open = createHistory(parentWindow.browser, function(active) {
      // Change the focus from window to active.
      contentWindow = active;
    });
    contentWindow = open({ name: iframe.name, parent: parentWindow, referrer: parentWindow.location.href });
    return contentWindow;
  }
};



// This is also necessary to prevent JSDOM from messing with window/document
DOM.HTMLFrameElement.prototype.setAttribute = function(name, value) {
  DOM.HTMLElement.prototype.setAttribute.call(this, name, value);
};

DOM.HTMLFrameElement.prototype._attrModified = function(name, value, oldValue) {
  if (name === 'src' && value) {

    const iframe = this;
    const url    = DOM.resourceLoader.resolve(iframe.ownerDocument, value);
    DOM.HTMLElement.prototype._attrModified.call(this, name, url, oldValue);

    // Don't load IFrame twice
    if (iframe.contentWindow.location.href === url)
      return;

    const ownerDocument = iframe.ownerDocument;

    // Point IFrame at new location and wait for it to load
    iframe.contentWindow.location = url
    // IFrame will load in a different window
    iframe.contentWindow.addEventListener('load', onload)

    function onload() {
      iframe.contentWindow.removeEventListener('load', onload);
      const event = ownerDocument.createEvent('HTMLEvents');
      event.initEvent('load', false, false);
      iframe.dispatchEvent(event);
    }

  } else if (name === 'name') {

    // Should be able to access parent.frames[name] -> this
    const windowName        = value;
    const { parentWindow }  = this.ownerDocument;
    const { contentWindow } = this;
    contentWindow.name = windowName;
    delete parentWindow[oldValue];
    parentWindow.__defineGetter__(windowName, ()=> this.contentWindow);

  } else {
    DOM.HTMLFrameElement.prototype._attrModified.call(this, name, value, oldValue);
  }

};
