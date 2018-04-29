// For handling JavaScript, mostly improvements to JSDOM

const DOM             = require('./index');
const resourceLoader  = require('jsdom/lib/jsdom/browser/resource-loader');
const reportException = require('jsdom/lib/jsdom/living/helpers/runtime-script-errors');
const VM              = require('vm');
const {
  HTMLScriptElementImpl
}                     = require('./impl');

// -- Patches to JSDOM --
Object.defineProperty(HTMLScriptElementImpl, 'init', {
  value: function(obj, privateData) {
    obj._attach = function(){
      Object.getPrototypeOf(this.constructor).prototype._attach.call(this)

      const script    = this;
      const document  = script.ownerDocument;

      if (script.src)
        // Script has a src attribute, load external resource.
        resourceLoader.load(script, script.src, {}, _eval.bind(script));
      else {
        const filename = script.id ?  `${document.URL}:#${script.id}` : `${document.URL}:script`;
        // Queue to be executed in order with all other scripts
        const executeInOrder = resourceLoader.enqueue(script, filename, executeInlineScript);
        // There are two scenarios:
        // - script element added to existing document, we should evaluate it
        //   immediately
        // - inline script element parsed, when we get here, we still don't have
        //   the element contents, so we have to wait before we can read and
        //   execute it
        if (document.readyState === 'loading')
          process.nextTick(executeInOrder);
        else
          executeInOrder();
      }

      // Execute inline script
      function executeInlineScript(code, filename) {
        _eval.call(script, script.textContent, filename);
        // script._eval(script.textContent, filename);
      }

    }
  }
});


function _eval(text, filename) {
  const typeString = this._getTypeString();
  const _defaultView = this._ownerDocument._defaultView;
  if (_defaultView && _defaultView._runScripts === 'dangerously' && jsMIMETypes.has(typeString.toLowerCase())) {
    this._ownerDocument._writeAfterElement = this;
    processJavaScript(this, text, filename);
    delete this._ownerDocument._writeAfterElement;
  }
}


function processJavaScript (element, buffer, filename) {
  const code = buffer.toString();
  // This may be called without code, e.g. script element that has no body yet
  if (!code)
    return;

  // Surpress JavaScript validation and execution
  const document = element.ownerDocument;
  const window   = document.defaultView;
  const browser  = window.top.browser;
  if (browser && !browser.runScripts)
    return;

  // This may be called without code, e.g. script element that has no body yet
  try {
    window.document._currentScript = element;
    window._evaluate(code, filename);
  } catch (error) {
    enhanceStackTrace(error, document.location.href);
    reportException(window, error);
  } finally {
    window.document._currentScript = null;
  }
};

function enhanceStackTrace(error, document_ref) {
  const partial = [];
  // "RangeError: Maximum call stack size exceeded" doesn't have a stack trace
  if (error.stack)
    for (let line of error.stack.split('\n')) {
      if (~line.indexOf('vm.js'))
        break;
      partial.push(line);
    }
  partial.push(`    in ${document_ref}`);
  error.stack = partial.join('\n');
  return error;
}

const jsMIMETypes = new Set([
  'application/ecmascript',
  'application/javascript',
  'application/x-ecmascript',
  'application/x-javascript',
  'text/ecmascript',
  'text/javascript',
  'text/javascript1.0',
  'text/javascript1.1',
  'text/javascript1.2',
  'text/javascript1.3',
  'text/javascript1.4',
  'text/javascript1.5',
  'text/jscript',
  'text/livescript',
  'text/x-ecmascript',
  'text/x-javascript'
]);
