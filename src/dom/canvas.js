const DOM             = require('./index');
const notImplemented  = require('jsdom/lib/jsdom/browser/utils').NOT_IMPLEMENTED;
const defineGetter    = require('jsdom/lib/jsdom/utils').defineGetter;
const defineSetter    = require('jsdom/lib/jsdom/utils').defineSetter;

// Work around jsdom <= 6.3.0 canvas bug
//
// When using jsdom with canvas support (with node-canvas), it's not possile to
// query canvas by id. The issue was initially reported in jsdom here:
// https://github.com/tmpvar/jsdom/issues/737
//
// The official fix landed into jsdom 6.3.0:
// https://github.com/tmpvar/jsdom/commit/f8d890342145bf7ee3ec5f4b12cbef88e7ced9de

DOM.Document.prototype._elementBuilders.canvas = function(doc, s) {
  var element = new DOM.HTMLCanvasElement(doc, s);
  element._init();
  return element;
}

DOM.HTMLCanvasElement.prototype._init = function() {
  let Canvas;
  try {
    Canvas = require("canvas");
  } catch (e) {}

  if (typeof Canvas === "function") { // in browserify, the require will succeed but return an empty object
    this._nodeCanvas = new Canvas(this.width, this.height);
  }
}

DOM.HTMLCanvasElement.prototype.getContext = function(contextId) {
  if (this._nodeCanvas) {
    return this._nodeCanvas.getContext(contextId) || null;
  }

  notImplemented("HTMLCanvasElement.prototype.getContext (without installing the canvas npm package)",
    this._ownerDocument._defaultView);
}

DOM.HTMLCanvasElement.prototype.toDataURL = function(type) {
  if (this._nodeCanvas) {
    return this._nodeCanvas.toDataURL(type);
  }

  notImplemented("HTMLCanvasElement.prototype.toDataURL (without installing the canvas npm package)",
    this._ownerDocument._defaultView);
}

defineGetter(DOM.HTMLCanvasElement.prototype, 'width', function() {
  const parsed = parseInt(this.getAttribute('width'));
  return (parsed < 0 || Number.isNaN(parsed)) ? 300 : parsed;
});

defineSetter(DOM.HTMLCanvasElement.prototype, 'width', function(v) {
  v = parseInt(v);
  v = (Number.isNaN(v) || v < 0) ? 300 : v;
  this.setAttribute('width', v);
});

defineGetter(DOM.HTMLCanvasElement.prototype, 'height', function() {
  const parsed = parseInt(this.getAttribute('height'));
  return (parsed < 0 || Number.isNaN(parsed)) ? 150 : parsed;
});

defineSetter(DOM.HTMLCanvasElement.prototype, 'height', function(v) {
  v = parseInt(v);
  v = (Number.isNaN(v) || v < 0) ? 150 : v;
  this.setAttribute('height', v);
});
