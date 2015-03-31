// Support for iframes.


const DOM = require('./index');


function loadFrame(frame) {
  // Close current content window in order to open a new one
  if (frame._contentWindow) {
    frame._contentWindow.close();
    delete frame._contentWindow;
  }

  function onload() {
    frame.contentWindow.removeEventListener('load', onload);
    const parentDocument = frame._ownerDocument;
    const loadEvent = parentDocument.createEvent('HTMLEvents');
    loadEvent.initEvent('load', false, false);
    frame.dispatchEvent(loadEvent);
  }

  // This is both an accessor to the contentWindow and a side-effect of creating
  // the window and loading the document based on the value of frame.src
  //
  // Not happy about this hack
  frame.contentWindow.addEventListener('load', onload);
}


function refreshAccessors(document) {
  const window = document._defaultView;
  const frames = document.querySelectorAll('iframe,frame');
  for (let i = 0; i < window._length; ++i)
    delete window[i];
  window._length = frames.length;
  Array.prototype.forEach.call(frames, function (frame, i) {
    window.__defineGetter__(i, ()=> frame.contentWindow );
  });
}

function refreshNameAccessor(frame) {
  const name = frame.getAttribute('name');
  // https://html.spec.whatwg.org/multipage/browsers.html#named-access-on-the-window-object:supported-property-names
  if (name) {
    // I do not know why this only works with _global and not with _defaultView :(
    const window = frame._ownerDocument._global;
    delete window[name];
    if (isInDocument(frame))
      window.__defineGetter__(name, ()=> frame.contentWindow );
  }
}

function isInDocument(el) {
  const document = el._ownerDocument;
  let   current = el;
  while ((current = current._parentNode))
    if (current === document)
      return true;
  return false;
}


DOM.HTMLFrameElement.prototype._attrModified = function (name, value, oldVal) {
  DOM.HTMLElement.prototype._attrModified.call(this, name, value, oldVal);
  if (name === 'name') {
    if (oldVal)
      // I do not know why this only works with _global and not with _defaultView :(
      delete this._ownerDocument._global[oldVal];
    refreshNameAccessor(this);
  } else if (name === 'src' && value !== oldVal && isInDocument(this))
    loadFrame(this);
};

DOM.HTMLFrameElement.prototype._detach = function () {
  DOM.HTMLElement.prototype._detach.call(this);
  if (this.contentWindow)
    this.contentWindow.close();
  refreshAccessors(this._ownerDocument);
  refreshNameAccessor(this);
};

DOM.HTMLFrameElement.prototype._attach = function () {
  DOM.HTMLElement.prototype._attach.call(this);
  loadFrame(this);
  refreshAccessors(this._ownerDocument);
  refreshNameAccessor(this);
};

DOM.HTMLFrameElement.prototype.__defineGetter__('contentDocument', function() {
  return this.contentWindow.document;
});

DOM.HTMLFrameElement.prototype.__defineGetter__('contentWindow', function() {
  if (!this._contentWindow) {
    const createHistory   = require('../history');
    const parentDocument  = this._ownerDocument;
    const parentWindow    = parentDocument.defaultView;

    // Need to bypass JSDOM's window/document creation and use ours
    const openWindow = createHistory(parentWindow.browser, (active)=> {
      // Change the focus from window to active.
      this._contentWindow = active;
    });

    const src = this.src.trim() === '' ? 'about:blank' : this.src;
    this._contentWindow = openWindow({
      name:     this.name,
      url:      DOM.resourceLoader.resolve(parentDocument, src),
      parent:   parentWindow,
      referrer: parentWindow.location.href
    });
  }
  return this._contentWindow;
});

