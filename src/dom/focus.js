// Support for element focus.


const DOM = require('./index');


const FOCUS_ELEMENTS = ['INPUT', 'SELECT', 'TEXTAREA', 'BUTTON', 'ANCHOR'];


// The element in focus.
//
// If no element has the focus, return the document.body.
DOM.HTMLDocument.prototype.__defineGetter__('activeElement', function() {
  return this._inFocus || this.body;
});

// Change the current element in focus (or null for blur)
function setFocus(document, element) {
  const inFocus = document._inFocus;
  if (element !== inFocus) {
    if (inFocus) {
      const onblur = document.createEvent('HTMLEvents');
      onblur.initEvent('blur', false, false);
      inFocus.dispatchEvent(onblur);
    }
    if (element) { // null to blur
      const onfocus = document.createEvent('HTMLEvents');
      onfocus.initEvent('focus', false, false);
      element.dispatchEvent(onfocus);
      document._inFocus = element;
      document.defaultView.browser.emit('focus', element);
    }
  }
}

// All HTML elements have a no-op focus/blur methods.
DOM.HTMLElement.prototype.focus = function() {
};
DOM.HTMLElement.prototype.blur = function() {
};

// Input controls have active focus/blur elements.  JSDOM implements these as
// no-op, so we have to over-ride each prototype individually.
const CONTROLS = [DOM.HTMLInputElement, DOM.HTMLSelectElement, DOM.HTMLTextAreaElement, DOM.HTMLButtonElement, DOM.HTMLAnchorElement];

CONTROLS.forEach(function(elementType) {
  elementType.prototype.focus = function() {
    setFocus(this.ownerDocument, this);
  };

  elementType.prototype.blur = function() {
    setFocus(this.ownerDocument, null);
  };

  // Capture the autofocus element and use it to change focus
  const setAttribute = elementType.prototype.setAttribute;
  elementType.prototype.setAttribute = function(name, value) {
    setAttribute.call(this, name, value);
    if (name === 'autofocus') {
      const document = this.ownerDocument;
      if (~FOCUS_ELEMENTS.indexOf(this.tagName) && !document._inFocus)
        this.focus();
    }
  };
});


// When changing focus onto form control, store the current value.  When changing
// focus to different control, if the value has changed, trigger a change event.
const INPUTS = [DOM.HTMLInputElement, DOM.HTMLTextAreaElement, DOM.HTMLSelectElement];

INPUTS.forEach(function(elementType) {
  // DEBUG elementType.prototype._eventDefaults.focus = function(event) {
  elementType.prototype._focus = function(event) {
    const element       = event.target;
    element._focusValue = element.value || '';
  };

  // DEBUG elementType.prototype._eventDefaults.blur = function(event) {
  elementType.prototype._blur = function(event) {
    const element     = event.target;
    const focusValue  = element._focusValue;
    if (focusValue !== element.value) { // null == undefined
      const change = element.ownerDocument.createEvent('HTMLEvents');
      change.initEvent('change', false, false);
      element.dispatchEvent(change);
    }
  };
});
