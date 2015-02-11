// For handling JavaScript, mostly improvements to JSDOM

const DOM = require('./dom');


// -- Patches to JSDOM --

// If you're using CoffeeScript, you get client-side support.
try {
  const CoffeeScript = require('coffee-script');
  DOM.languageProcessors.coffeescript = function(element, code, filename) {
    this.javascript(element, CoffeeScript.compile(code), filename);
  };
} catch (error) {
  // Oh, well
}


// If JSDOM encounters a JS error, it fires on the element.  We expect it to be
// fires on the Window.  We also want better stack traces.
DOM.languageProcessors.javascript = function(element, code, filename) {
  // This may be called without code, e.g. script element that has no body yet
  if (!code)
    return;

  // Surpress JavaScript validation and execution
  const document    = element.ownerDocument;
  const window      = document.parentWindow;
  const browser     = window.top.browser;
  if (browser && !browser.runScripts)
    return;

  // This may be called without code, e.g. script element that has no body yet
  try {
    window._evaluate(code, filename);
  } catch (error) {
    if (error.hasOwnProperty('stack')) {
      const cast = new Error(error.message || error.toString());
      cast.stack = error.stack;
      document.raise('error', error.message, { exception: cast });
    } else
      document.raise('error', error.message, { exception: error });
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

    if (script.src) {
      // Script has a src attribute, load external resource.
      DOM.resourceLoader.load(script, script.src, script._eval);
    } else {
      const filename = script.id ?  `${document.URL}:#${script.id}` : `${document.URL}:script`;
      // Execute inline script
      function executeInlineScript() {
        script._eval(script.textContent, filename);
      };
      // Queue to be executed in order with all other scripts
      const executeInOrder = DOM.resourceLoader.enqueue(script, executeInlineScript, filename);
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
  });
};


// Fix resource loading to keep track of in-progress requests. Need this to wait
// for all resources (mainly JavaScript) to complete loading before terminating
// browser.wait.
DOM.resourceLoader.load = function(element, href, callback) {
  const document      = element.ownerDocument;
  const window        = document.parentWindow;
  const tagName       = element.tagName.toLowerCase();
  const loadResource  = document.implementation._hasFeature('FetchExternalResources', tagName);
  const url           = DOM.resourceLoader.resolve(document, href);

  if (loadResource) {
    const inOrder = this.enqueue(element, loaded, url);
    window._eventQueue.http('GET', url, { target: element }, inOrder);
  }

  // This guarantees that all scripts are executed in order
  function loaded(response) {
    callback.call(element, response.body.toString(), url.pathname);
  }
};

