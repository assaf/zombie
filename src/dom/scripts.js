// For handling JavaScript, mostly improvements to JSDOM

const DOM             = require('./index');
const resourceLoader  = require('jsdom/lib/jsdom/browser/resource-loader');


// -- Patches to JSDOM --

// If JSDOM encounters a JS error, it fires on the element.  We expect it to be
// fires on the Window.  We also want better stack traces.
DOM.languageProcessors.javascript = function(element, buffer, filename) {
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
    if (error.hasOwnProperty('stack')) {
      const cast = new Error(error.message || error.toString());
      cast.stack = error.stack;
      document.raise('error', error.message, { exception: cast });
    } else
      document.raise('error', error.message, { exception: error });
  } finally {
    window.document._currentScript = null;
  }
};


// HTML5 parser doesn't play well with JSDOM so we need this trickey to sort of
// get script execution to work properly.
//
// Basically JSDOM listend for when the script tag is added to the DOM and
// attemps to evaluate at, but the script has no contents at that point in
// time.  This adds just enough delay for the inline script's content to be
// parsed and ready for processing.
DOM.HTMLScriptElement._init = function() {
  this.addEventListener('DOMNodeInsertedIntoDocument', function() {
    const script    = this;
    const document  = script.ownerDocument;

    if (script.src)
      // Script has a src attribute, load external resource.
      resourceLoader.load(script, script.src, script._eval);
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
      script._eval(script.textContent, filename);
    }
  });
};

