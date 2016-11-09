require('jsdom');  // work-around for node.js import of jsdom Windows.js before jsdom living module

const assert            = require('assert');
const Assert            = require('./assert');
const Bluebird          = require('bluebird');
const Tabs              = require('./tabs');
const Console           = require('./console');
const Cookies           = require('./cookies');
const debug             = require('debug');
const DOM               = require('./dom');
const { EventEmitter }  = require('events');
const EventLoop         = require('./eventloop');
const { format }        = require('util');
const Fetch             = require('./fetch');
const File              = require('fs');
const Mime              = require('mime');
const ms                = require('ms');
const Path              = require('path');
const Pipeline          = require('./pipeline');
const reroute           = require('./reroute');
const Storages          = require('./storage');
const Tough             = require('tough-cookie');
const { Cookie }        = Tough;
const URL               = require('url');
const Utils             = require('jsdom/lib/jsdom/utils');
const fileListSymbols   = require('jsdom/lib/jsdom/living/filelist-symbols'); 


// Version number.  We get this from package.json.
const VERSION = require(`${__dirname}/../package.json`).version;

// Browser options you can set when creating new browser, or on browser instance.
const BROWSER_OPTIONS  = ['features', 'headers', 'waitDuration',
                          'proxy', 'referrer', 'silent', 'site', 'strictSSL', 'userAgent',
                          'language', 'runScripts', 'localAddress'];

// These features are set on/off by default.
// Note that default values are actually prescribed where they are used,
// by calling hasFeature with name and default
const DEFAULT_FEATURES  = 'scripts no-css no-img iframe';

const MOUSE_EVENT_NAMES = ['mousedown', 'mousemove', 'mouseup'];


// Use the browser to open up new windows and load documents.
//
// The browser maintains state for cookies and local storage.
class Browser extends EventEmitter {

  constructor(options = {}) {
    super();
    // Used for assertions
    this.assert     = new Assert(this);
    this.cookies    = new Cookies();
    // Shared by all windows.
    this.console    = new Console(this);
    // Start with no this referrer.
    this.referrer   = null;
    // Open tabs.
    this.tabs       = new Tabs(this);
    // New pipeline for this browser.
    this.pipeline   = new Pipeline(this);

    // The browser event loop.
    this._eventLoop = new EventLoop(this);

    // Returns all errors reported while loading this window.
    this.errors     = [];

    this._storages  = new Storages();

    // The window that is currently in scope, some JS functions need this, e.g.
    // when closing a window, you need to determine whether caller (window in
    // scope) is same as window.opener
    this._windowInScope = null;

    this._debug         = Browser._debug;

    // Message written to window.console.  Level is log, info, error, etc.
    //
    // All output goes to stdout, except when browser.silent = true and output
    // only shown when debugging (DEBUG=zombie).
    this
      .on('console', (level, message)=> {
        if (this.silent)
          this._debug(`>> ${message}`);
        else
          console.log(message);
      })
      .on('log', (...args)=> {
        // Message written to browser.log.
        this._debug(format(...args));
      });

    // Logging resources
    this
      .on('request', (request)=> request)
      .on('response', (request, response)=> {
        this._debug('%s %s => %s', request.method, response.url, response.status);
      })
      .on('redirect', (request, response)=> {
        this._debug('%s %s => %s %s', request.method, request.url, response.status, response.headers.get('Location'));
      })
      .on('loaded', (document)=> {
        this._debug('Loaded document %s', document.location.href);
      })
      .on('xhr', (eventName, url)=> {
        this._debug('XHR %s %s', eventName, url);
      });

    // Logging windows/tabs/navigation
    this
      .on('opened', (window)=> {
        this._debug('Opened window %s %s', window.location.href, window.name || '');
      })
      .on('closed', (window)=> {
        this._debug('Closed window %s %s', window.location.href, window.name || '');
      });

    // Switching tabs/windows fires blur/focus event on active window/element
    this
      .on('active', (window)=> {
        // Window becomes inactive
        const winFocus = window.document.createEvent('HTMLEvents');
        winFocus.initEvent('focus', false, false);
        window.dispatchEvent(winFocus);

        if (window.document.activeElement) {
          const elemFocus = window.document.createEvent('HTMLEvents');
          elemFocus.initEvent('focus', false, false);
          window.document.activeElement.dispatchEvent(elemFocus);
        }
      })
      .on('inactive', (window)=> {
        // Window becomes inactive
        if (window.document.activeElement) {
          const elemBlur = window.document.createEvent('HTMLEvents');
          elemBlur.initEvent('blur', false, false);
          window.document.activeElement.dispatchEvent(elemBlur);
        }
        const winBlur = window.document.createEvent('HTMLEvents');
        winBlur.initEvent('blur', false, false);
        window.dispatchEvent(winBlur);
      });

    // Logging navigation
    this
      .on('link', (url)=> {
        this._debug('Follow link to %s', url);
      })
      .on('submit', (url)=> {
        this._debug('Submit form to %s', url);
      });

    // Logging event loop
    this._eventLoop
      .on('setTimeout', (fn, delay)=> {
        this._debug('Fired setTimeout after %dms delay', delay);
        this.emit('setTimeout', fn, delay);
      })
      .on('setInterval', (fn, interval)=> {
        this._debug('Fired setInterval every %dms', interval);
        this.emit('setInterval', fn, interval);
      })
      .on('serverEvent', ()=> {
        this._debug('Server initiated event');
        this.emit('serverEvent');
      })
      .on('idle', (timedOut)=> {
        if (timedOut)
          this._debug('Event loop timed out');
        else
          this._debug('Event loop is empty');
        this.emit('idle');
      })
      .on('error', (error)=> {
        this.emit('error', error);
      });

    // Make sure we don't blow up Node when we get a JS error, but dump error to console.  Also, catch any errors
    // reported while processing resources/JavaScript.
    this.on('error', (error)=> {
      this.errors.push(error);
      this._debug(error.stack);
    });

    // Sets the browser options.
    options = options || {};
    for (let name of BROWSER_OPTIONS) {
      this[name] = options.hasOwnProperty(name) ?
        options[name] :
        (Browser[name] || null);
    }

    // Last, run all extensions in order.
    for (let extension of Browser._extensions)
      extension(this);
  }


  // Returns true if the given feature is enabled.
  //
  // If the feature is listed, then it is enabled.  If the feature is listed
  // with "no-" prefix, then it is disabled.  If the feature is missing, return
  // the default value.
  hasFeature(name, defaultValue = true) {
    const features = (this.features || '').split(/\s+/);
    return ~features.indexOf(name) ? true :
           ~features.indexOf(`no-${name}`) ? false :
           defaultValue;
  }


  // Return a new browser with a snapshot of this browser's state.
  // Any changes to the forked browser's state do not affect this browser.
  fork() {
    throw new Error('Not implemented');
  }


  // Windows
  // -------

  // Returns the currently open window
  get window() {
    return this.tabs.current;
  }

  // Open new browser window.
  open({ url, name, referrer } = {}) {
    return this.tabs.open({ url, name, referrer });
  }

  // browser.error => Error
  //
  // Returns the last error reported while loading this window.
  get error() {
    return this.errors[this.errors.length - 1];
  }


  // Events
  // ------

  // Waits for the browser to complete loading resources and processing JavaScript events.
  //
  // Accepts two parameters, both optional:
  // options   - Options that determine how long to wait (see below)
  // callback  - Called with error or null and browser
  //
  // To determine how long to wait:
  // duration  - Do not wait more than this duration (milliseconds or string of
  //             the form "5s"). Defaults to "5s" (see Browser.waitDuration).
  // element   - Stop when this element(s) appear in the DOM.
  // function  - Stop when function returns true; this function is called with
  //             the active window and expected time to the next event (0 to
  //             Infinity).
  //
  // As a convenience you can also pass the duration directly.
  //
  // Without a callback, this method returns a promise.
  wait(options, callback) {
    assert(this.window, new Error('No window open'));
    if (arguments.length === 1 && typeof options === 'function')
      [callback, options] = [options, null];
    assert(!callback || typeof callback === 'function', 'Second argument expected to be a callback function or null');

    // Support all sort of shortcuts for options. Unofficial.
    const duration =
      (typeof options === 'number') ? options :
      (typeof options === 'string') ? options :
      (options && options.duration || this.waitDuration || '5s');
    // Support 500 (ms) as well as "5s"
    const waitDuration = ms(duration.toString());

    function completionFromElement(element) {
      return function(window) {
        return !!window.document.querySelector(element);
      };
    }

    const completionFunction =
      (typeof options === 'function') ? options :
      (options && options.element) ? completionFromElement(options.element) :
      (options && options.function);

    const { _eventLoop } = this;
    if (callback)
      _eventLoop.wait(waitDuration, completionFunction, callback);
    else
      return Bluebird.promisify(_eventLoop.wait.bind(_eventLoop))(waitDuration, completionFunction);
  }


  // Waits for the browser to get a single event from any EventSource,
  // then completes loading resources and processing JavaScript events.
  //
  // Accepts an optional callback which is called with error or nothing
  //
  // Without a callback, this method returns a promise.
  waitForServer(options, callback) {
    assert(this.window, new Error('No window open'));
    if (arguments.length === 1 && typeof options === 'function')
      [callback, options] = [options, null];

    if (callback) {
      this._eventLoop.once('serverEvent', ()=> {
        this.wait(options, callback);
      });
      return null;
    }

    return new Promise((resolve)=> {
      this._eventLoop.once('serverEvent', ()=> {
        resolve(this.wait(options, null));
      });
    });
  }


  // Various methods use this with a callback, or return a lazy promise (e.g.
  // visit, click, fire)
  _wait(options, callback) {
    if (callback) {
      this.wait(options, callback);
      return null;
    }

    let promise = null;
    const lazyResolve = ()=> {
      if (!promise)
        promise = this.wait(options, null);
      return promise;
    };
    // Returns equivalent of a promise that only starts evaluating when you
    // call then() or catch() on it.
    return {
      then(resolved, rejected) {
        return lazyResolve().then(resolved, rejected);
      },
      catch(rejected) {
        return lazyResolve().then(null, rejected);
      }
    };
  }


  // Fire a DOM event.  You can use this to simulate a DOM event, e.g. clicking
  // a link.  These events will bubble up and can be cancelled.  Like `wait`
  // this method takes an optional callback and returns a promise.
  //
  // name - Even name (e.g `click`)
  // target - Target element (e.g a link)
  // callback - Called with error or nothing
  //
  // If called without callback, returns a promise
  fire(selector, eventName, callback) {
    assert(this.window, 'No window open');
    const target = this.query(selector);
    assert(target && target.dispatchEvent, 'No target element (note: call with selector/element, event name and callback)');

    const eventType = ~MOUSE_EVENT_NAMES.indexOf(eventName) ? 'MouseEvents' : 'HTMLEvents';
    const event = this.document.createEvent(eventType);
    event.initEvent(eventName, true, true);
    target.dispatchEvent(event);
    return this._wait(null, callback);
  }

  // Click on the element and returns a promise.
  //
  // selector - Element or CSS selector
  // callback - Called with error or nothing
  //
  // If called without callback, returns a promise
  click(selector, callback) {
    return this.fire(selector, 'click', callback);
  }

  // Dispatch asynchronously.  Returns true if preventDefault was set.
  dispatchEvent(selector, event) {
    assert(this.window, 'No window open');
    const target = this.query(selector);
    return target.dispatchEvent(event);
  }


  // Accessors
  // ---------

  // browser.queryAll(selector, context?) => Array
  //
  // Evaluates the CSS selector against the document (or context node) and return array of nodes.
  // (Unlike `document.querySelectorAll` that returns a node list).
  queryAll(selector = 'html', context = this.document) {
    assert(this.document && this.document.documentElement, 'No open window with an HTML document');

    if (Array.isArray(selector))
      return selector;
    if (selector instanceof DOM.Element)
      return [selector];
    if (selector) {
      const elements = context.querySelectorAll(selector);
      return Array.from(elements);
    } else
      return [];
  }

  // browser.query(selector, context?) => Element
  //
  // Evaluates the CSS selector against the document (or context node) and return an element.
  query(selector = 'html', context = this.document) {
    assert(this.document && this.document.documentElement, 'No open window with an HTML document');

    if (selector instanceof DOM.Element)
      return selector;
    return selector ? context.querySelector(selector) : context;
  }

  // WebKit offers this.
  $$(selector, context) {
    return this.query(selector, context);
  }

  // browser.querySelector(selector) => Element
  //
  // Select a single element (first match) and return it.
  //
  // selector - CSS selector
  //
  // Returns an Element or null
  querySelector(selector) {
    assert(this.document && this.document.documentElement, 'No open window with an HTML document');
    return this.document.querySelector(selector);
  }

  // browser.querySelectorAll(selector) => NodeList
  //
  // Select multiple elements and return a static node list.
  //
  // selector - CSS selector
  //
  // Returns a NodeList or null
  querySelectorAll(selector) {
    assert(this.document && this.document.documentElement, 'No open window with an HTML document');
    return this.document.querySelectorAll(selector);
  }

  // browser.text(selector, context?) => String
  //
  // Returns the text contents of the selected elements.
  //
  // selector - CSS selector (if missing, entire document)
  // context - Context element (if missing, uses document)
  //
  // Returns a string
  text(selector = 'html', context = this.document) {
    assert(this.document, 'No window open');

    if (this.document.documentElement)
      return this.queryAll(selector, context)
        .map(elem => elem.textContent)
        .join('')
        .trim()
        .replace(/\s+/g, ' ');
    else
      return (this.source ? this.source.toString : '');
  }


  // browser.html(selector?, context?) => String
  //
  // Returns the HTML contents of the selected elements.
  //
  // selector - CSS selector (if missing, entire document)
  // context - Context element (if missing, uses document)
  //
  // Returns a string
  html(selector = 'html', context = this.document) {
    assert(this.document, 'No window open');

    if (this.document.documentElement)
      return this.queryAll(selector, context)
        .map(elem => elem.outerHTML.trim())
        .join('');
    else
      return (this.source ? this.source.toString : '');
  }


  // browser.xpath(expression, context?) => XPathResult
  //
  // Evaluates the XPath expression against the document (or context node) and return the XPath result.  Shortcut for
  // `document.evaluate`.
  xpath(expression, context = null) {
    return this.document.evaluate(expression, context || this.document.documentElement, null, DOM.XPathResult.ANY_TYPE);
  }

  // browser.document => Document
  //
  // Returns the main window's document. Only valid after opening a document (see `browser.open`).
  get document() {
    return this.window && this.window.document;
  }

  // browser.body => Element
  //
  // Returns the body Element of the current document.
  get body() {
    return this.querySelector('body');
  }

  // Element that has the current focus.
  get activeElement() {
    return this.document && this.document.activeElement;
  }

  // Close all windows, clean state, etc.  This doesn't do anything the garbage
  // collector doesn't already do, so you don't need to call this.
  //
  // But because it destroys the browser state, it's quite useful for detecting
  // weird behavior bugs, e.g. an event loop that keeps running.  That's why
  // the test suite uses this method.
  destroy() {
    if (this.tabs) {
      this.tabs.closeAll();
      this.tabs = null;
    }
  }


  // Navigation
  // ----------

  // browser.visit(url, callback?)
  //
  // Loads document from the specified URL, processes events and calls the callback, or returns a promise.
  visit(url, options, callback) {
    if (arguments.length < 3 && typeof options === 'function')
      [options, callback] = [{}, options];

    const site = /^(https?:|file:)/i.test(this.site) ? this.site : `http://${this.site || 'localhost'}/`;
    url = Utils.resolveHref(site, URL.format(url));

    if (this.window)
      this.tabs.close(this.window);
    this.errors = [];
    this.tabs.open({ url: url, referrer: this.referrer });
    return this._wait(options, callback);
  }


  // browser.load(html, callback)
  //
  // Loads the HTML, processes events and calls the callback.
  //
  // Without a callback, returns a promise.
  load(html, callback) {
    if (this.window)
      this.tabs.close(this.window);
    this.errors = [];
    this.tabs.open({ html: html });
    return this._wait(null, callback);
  }


  // browser.location => Location
  //
  // Return the location of the current document (same as `window.location`).
  get location() {
    return this.window && this.window.location;
  }

  // browser.location = url
  //
  // Changes document location, loads new document if necessary (same as setting `window.location`).
  set location(url) {
    if (this.window)
      this.window.location = url;
    else
      this.open({ url: url });
  }

  // browser.url => String
  //
  // Return the URL of the current document (same as `document.URL`).
  get url() {
    return this.window && this.window.location.href;
  }

  // browser.link(selector) : Element
  //
  // Finds and returns a link by its text content or selector.
  link(selector) {
    assert(this.document && this.document.documentElement, 'No open window with an HTML document');
    // If the link has already been queried, return itself
    if (selector instanceof DOM.Element)
      return selector;

    try {
      const link = this.querySelector(selector);
      if (link && link.tagName === 'A')
        return link;
    } catch (error) {
      /* eslint no-empty:0 */
    }
    for (let elem of Array.from(this.querySelectorAll('body a'))) {
      if (elem.textContent.trim() === selector)
        return elem;
    }
    return null;
  }

  // browser.clickLink(selector, callback)
  //
  // Clicks on a link. Clicking on a link can trigger other events, load new page, etc: use a callback to be notified of
  // completion.  Finds link by text content or selector.
  //
  // selector - CSS selector or link text
  // callback - Called with two arguments: error and browser
  clickLink(selector, callback) {
    const link = this.link(selector);
    assert(link, `No link matching '${selector}'`);
    return this.click(link, callback);
  }

  // Return the history object.
  get history() {
    if (!this.window)
      this.open();
    return this.window.history;
  }

  // Navigate back in history.
  back(callback) {
    this.window.history.back();
    return this._wait(null, callback);
  }

  // Reloads current page.
  reload(callback) {
    this.window.location.reload();
    return this._wait(null, callback);
  }


  // browser.saveHistory() => String
  //
  // Save history to a text string.  You can use this to load the data later on using `browser.loadHistory`.
  saveHistory() {
    return this.window.history.save();
  }

  // browser.loadHistory(String)
  //
  // Load history from a text string (e.g. previously created using `browser.saveHistory`.
  loadHistory(serialized) {
    this.window.history.load(serialized);
  }


  // Forms
  // -----

  // browser.field(selector) : Element
  //
  // Find and return an input field (`INPUT`, `TEXTAREA` or `SELECT`) based on a CSS selector, field name (its `name`
  // attribute) or the text value of a label associated with that field (case sensitive, but ignores leading/trailing
  // spaces).
  field(selector) {
    assert(this.document && this.document.documentElement, 'No open window with an HTML document');
    // If the field has already been queried, return itself
    if (selector instanceof DOM.Element)
      return selector;

    try {
      // Try more specific selector first.
      const field = this.query(selector);
      if (field && (field.tagName === 'INPUT' || field.tagName === 'TEXTAREA' || field.tagName === 'SELECT'))
        return field;
    } catch (error) {
      // Invalid selector, but may be valid field name
    }

    // Use field name (case sensitive).
    for (let elem of this.queryAll('input[name],textarea[name],select[name]')) {
      if (elem.getAttribute('name') === selector)
        return elem;
    }

    // Try finding field from label.
    for (let label of this.queryAll('label')) {
      if (label.textContent.trim() === selector) {
        // nLabel can either reference field or enclose it
        const forAttr = label.getAttribute('for');
        return forAttr ?
          this.document.getElementById(forAttr) :
          label.querySelector('input,textarea,select');
      }
    }
    return null;
  }


  // browser.focus(selector) : Element
  //
  // Turns focus to the selected input field.  Shortcut for calling `field(selector).focus()`.
  focus(selector) {
    const field = this.field(selector) || this.query(selector);
    assert(field, `No form field matching '${selector}'`);
    field.focus();
    return this;
  }


  // browser.fill(selector, value) => this
  //
  // Fill in a field: input field or text area.
  //
  // selector - CSS selector, field name or text of the field label
  // value - Field value
  //
  // Returns this.
  fill(selector, value) {
    const field = this.field(selector);
    assert(field && (field.tagName === 'TEXTAREA' || (field.tagName === 'INPUT')), `No INPUT matching '${selector}'`);
    assert(!field.disabled, 'This INPUT field is disabled');
    assert(!field.readonly, 'This INPUT field is readonly');

    // Switch focus to field, change value and emit the input event (HTML5)
    field.focus();
    field.value = value;
    this.fire(field, 'input', false);
    // Switch focus out of field, if value changed, this will emit change event
    field.blur();
    return this;
  }

  _setCheckbox(selector, value) {
    const field = this.field(selector);
    assert(field && field.tagName === 'INPUT' && field.type === 'checkbox', `No checkbox INPUT matching '${selector}'`);
    assert(!field.disabled, 'This INPUT field is disabled');
    assert(!field.readonly, 'This INPUT field is readonly');

    if (field.checked ^ value)
      field.click();
    return this;
  }

  // browser.check(selector) => this
  //
  // Checks a checkbox.
  //
  // selector - CSS selector, field name or text of the field label
  //
  // Returns this.
  check(selector) {
    return this._setCheckbox(selector, true);
  }

  // browser.uncheck(selector) => this
  //
  // Unchecks a checkbox.
  //
  // selector - CSS selector, field name or text of the field label
  //
  // Returns this.
  uncheck(selector) {
    return this._setCheckbox(selector, false);
  }

  // browser.choose(selector) => this
  //
  // Selects a radio box option.
  //
  // selector - CSS selector, field value or text of the field label
  //
  // Returns this.
  choose(selector) {
    const field = this.field(selector) || this.field(`input[type=radio][value=\'${escape(selector)}\']`);
    assert(field && field.tagName === 'INPUT' && field.type === 'radio', `No radio INPUT matching '${selector}'`);

    field.click();
    return this;
  }

  _findOption(selector, value) {
    const field = this.field(selector);
    assert(field && field.tagName === 'SELECT', `No SELECT matching '${selector}'`);
    assert(!field.disabled, 'This SELECT field is disabled');
    assert(!field.readonly, 'This SELECT field is readonly');

    const options = Array.from(field.options);
    for (let option of options) {
      if (option.value === value)
        return option;
    }
    for (let option of options) {
      if (option.label === value)
        return option;
    }
    for (let option of options) {
      if (option.textContent.trim() === value)
        return option;
    }
    throw new Error(`No OPTION '${value}'`);
  }

  // browser.select(selector, value) => this
  //
  // Selects an option.
  //
  // selector - CSS selector, field name or text of the field label
  // value - Value (or label) or option to select
  //
  // Returns this.
  select(selector, value) {
    const option = this._findOption(selector, value);
    this.selectOption(option);
    return this;
  }

  // browser.selectOption(option) => this
  //
  // Selects an option.
  //
  // option - option to select
  //
  // Returns this.
  selectOption(selector) {
    const option = this.query(selector);
    if (option && !option.selected) {
      const select = this.xpath('./ancestor::select', option).iterateNext();
      option.selected = true;
      select.focus();
      this.fire(select, 'change', false);
    }
    return this;
  }

  // browser.unselect(selector, value) => this
  //
  // Unselects an option.
  //
  // selector - CSS selector, field name or text of the field label
  // value - Value (or label) or option to unselect
  //
  // Returns this.
  unselect(selector, value) {
    const option = this._findOption(selector, value);
    this.unselectOption(option);
    return this;
  }

  // browser.unselectOption(option) => this
  //
  // Unselects an option.
  //
  // selector - selector or option to unselect
  //
  // Returns this.
  unselectOption(selector) {
    const option = this.query(selector);
    if (option && option.selected) {
      const select = this.xpath('./ancestor::select', option).iterateNext();
      assert(select.multiple, 'Cannot unselect in single select');
      option.selected = false;
      select.focus();
      this.fire(select, 'change', false);
    }
    return this;
  }

  // browser.attach(selector, filename) => this
  //
  // Attaches a file to the specified input field.  The second argument is the file name.
  //
  // Returns this.
  attach(selector, filename) {
    const field = this.field(selector);
    assert(field && field.tagName === 'INPUT' && field.type === 'file', `No file INPUT matching '${selector}'`);

    if (filename) {
      const stat = File.statSync(filename);
      const file = new (this.window.File)();
      file.name = Path.basename(filename);
      file.type = Mime.lookup(filename);
      file.size = stat.size;

      field.value = filename;
      const oldFiles = field.files;
      if (typeof(oldFiles) !== 'array') {
        // JSDOM does not support an API to mock a list of files, and the default
        // type of the 'files' attribute is a FileList object. 
        Object.defineProperty(field, 'files', {
          value: []
        });
      }
      field.files.push(file);
    }
    field.focus();
    this.fire(field, 'change', false);
    return this;
  }

  // browser.button(selector) : Element
  //
  // Finds a button using CSS selector, button name or button text (`BUTTON` or `INPUT` element).
  //
  // selector - CSS selector, button name or text of BUTTON element
  button(selector) {
    assert(this.document && this.document.documentElement, 'No open window with an HTML document');
    // If the button has already been queried, return itself
    if (selector instanceof DOM.Element)
      return selector;

    try {
      const button = this.querySelector(selector);
      if (button && (button.tagName === 'BUTTON' || button.tagName === 'INPUT'))
        return button;
    } catch (error) {
    }
    for (let elem of Array.from(this.querySelectorAll('button'))) {
      if (elem.textContent.trim() === selector)
        return elem;
    }

    const inputs = Array.from(this.querySelectorAll('input[type=submit],input[type=button],input[type=reset],button'));
    for (let input of inputs) {
      if (input.name === selector)
        return input;
    }
    for (let input of inputs) {
      if (input.value === selector)
        return input;
    }
    return null;
  }

  // browser.pressButton(selector, callback)
  //
  // Press a button (button element or input of type `submit`).  Typically this will submit the form.  Use the callback
  // to wait for the from submission, page to load and all events run their course.
  //
  // selector - CSS selector, button name or text of BUTTON element
  // callback - Called with two arguments: null and browser
  pressButton(selector, callback) {
    const button = this.button(selector);
    assert(button, `No BUTTON '${selector}'`);
    assert(!button.disabled, 'This button is disabled');
    button.focus();
    return this.fire(button, 'click', callback);
  }


  // -- Cookies --


  // Returns cookie that best matches the identifier.
  //
  // identifier - Identifies which cookie to return
  // allProperties - If true, return all cookie properties, other just the value
  //
  // Identifier is either the cookie name, in which case the cookie domain is
  // determined from the currently open Web page, and the cookie path is "/".
  //
  // Or the identifier can be an object specifying:
  // name   - The cookie name
  // domain - The cookie domain (defaults to hostname of currently open page)
  // path   - The cookie path (defaults to "/")
  //
  // Returns cookie value, or cookie object (see setCookie).
  getCookie(identifier, allProperties) {
    identifier = this._cookieIdentifier(identifier);
    assert(identifier.name, 'Missing cookie name');
    assert(identifier.domain, 'No domain specified and no open page');

    const cookie = this.cookies.select(identifier)[0];
    return cookie ?
      (allProperties ?
        this._cookieProperties(cookie) :
        cookie.value) :
      null;
  }

  // Deletes cookie that best matches the identifier.
  //
  // identifier - Identifies which cookie to return
  //
  // Identifier is either the cookie name, in which case the cookie domain is
  // determined from the currently open Web page, and the cookie path is "/".
  //
  // Or the identifier can be an object specifying:
  // name   - The cookie name
  // domain - The cookie domain (defaults to hostname of currently open page)
  // path   - The cookie path (defaults to "/")
  //
  // Returns true if cookie delete.
  deleteCookie(identifier) {
    identifier = this._cookieIdentifier(identifier);
    assert(identifier.name, 'Missing cookie name');
    assert(identifier.domain, 'No domain specified and no open page');

    const cookie = this.cookies.select(identifier)[0];
    if (cookie)
      this.cookies.delete(cookie);
    return !!cookie;
  }

  // Sets a cookie.
  //
  // You can call this function with two arguments to set a session cookie: the
  // cookie value and cookie name.  The domain is determined from the current
  // page URL, and the path is always "/".
  //
  // Or you can call it with a single argument, with all cookie options:
  // name     - Name of the cookie
  // value    - Value of the cookie
  // domain   - The cookie domain (e.g example.com, .example.com)
  // path     - The cookie path
  // expires  - Time when cookie expires
  // maxAge   - How long before cookie expires
  // secure   - True for HTTPS only cookie
  // httpOnly - True if cookie not accessible from JS
  setCookie(nameOrOptions, value) {
    const domain = this.location && this.location.hostname;
    if (typeof nameOrOptions === 'string')
      this.cookies.set({
        name:     nameOrOptions,
        value:    value || '',
        domain:   domain,
        path:     '/',
        secure:   false,
        httpOnly: false
      });
    else {
      assert(nameOrOptions.name, 'Missing cookie name');
      this.cookies.set({
        name:       nameOrOptions.name,
        value:      nameOrOptions.value || value || '',
        domain:     nameOrOptions.domain || domain,
        path:       nameOrOptions.path || '/',
        secure:     !!nameOrOptions.secure,
        httpOnly:   !!nameOrOptions.httpOnly,
        expires:    nameOrOptions.expires,
        'max-age':  nameOrOptions['max-age']
      });
    }
  }

  // Deletes all cookies.
  deleteCookies() {
    this.cookies.deleteAll();
  }

  // Save cookies to a text string.  You can use this to load them back
  // later on using `Browser.loadCookies`.
  saveCookies() {
    const serialized = [`# Saved on ${new Date().toISOString()}`];
    for (let cookie of this.cookies.sort(Tough.cookieCompare))
      serialized.push(cookie.toString());
    return serialized.join('\n') + '\n';
  }

  // Load cookies from a text string (e.g. previously created using
  // `Browser.saveCookies`.
  loadCookies(serialized) {
    for (let line of serialized.split(/\n+/)) {
      line = line.trim();
      if (line && line[0] !== `#`)
        this.cookies.push(Cookie.parse(line));
    }
  }

  // Converts Tough Cookie object into Zombie cookie representation.
  _cookieProperties(cookie) {
    const properties = {
      name:   cookie.key,
      value:  cookie.value,
      domain: cookie.domain,
      path:   cookie.path
    };
    if (cookie.secure)
      properties.secure = true;
    if (cookie.httpOnly)
      properties.httpOnly = true;
    if (cookie.expires && cookie.expires < Infinity)
      properties.expires = cookie.expires;
    return properties;
  }

  // Converts cookie name/identifier into an identifier object.
  _cookieIdentifier(identifier) {
    const location = this.location;
    const domain = location && location.hostname;
    const path   = location && location.pathname || '/';
    return {
      name:   identifier.name || identifier,
      domain: identifier.domain || domain,
      path:   identifier.path || path
    };
  }


  // -- Local/Session Storage --


  // Returns local Storage based on the document origin (hostname/port). This is the same storage area you can access
  // from any document of that origin.
  localStorage(host) {
    return this._storages.local(host);
  }

  // Returns session Storage based on the document origin (hostname/port). This is the same storage area you can access
  // from any document of that origin.
  sessionStorage(host) {
    return this._storages.session(host);
  }

  // Save local/session storage to a text string.  You can use this to load the data later on using
  // `browser.loadStorage`.
  saveStorage() {
    return this._storages.save();
  }

  // Load local/session storage from a text string (e.g. previously created using `browser.saveStorage`.
  loadStorage(serialized) {
    this._storages.load(serialized);
  }


  // Scripts
  // -------

  // Evaluates a JavaScript expression in the context of the current window and returns the result.  When evaluating
  // external script, also include filename.
  //
  // You can also use this to evaluate a function in the context of the window: for timers and asynchronous callbacks
  // (e.g. XHR).
  evaluate(code, filename) {
    if (!this.window)
      this.open();
    return this.window._evaluate(code, filename);
  }


  // Resources
  // ---------

  fetch(input, init) {
    return this.pipeline._fetch(input, init);
  }

  // Returns all resources loaded by currently open window.
  get resources() {
    return this.window && this.window.resources;
  }

  // Get Request associated with currently open window
  get request() {
    return this.window && this.window._request || null;
  }

  // Get Response associated with currently open window
  get response() {
    return this.window && this.window._response || null;
  }

  // Get the status code of the response associated with this window
  get status() {
    const { response } = this;
    return response ? response.status : 0;
  }

  get statusCode() {
    return this.status;
  }

  // Return true if last response had status code 200 .. 299
  get success() {
    const { status } = this;
    return status >= 200 && status < 300;
  }

  // Returns true if the last response followed a redirect
  get redirected() {
    const { request } = this;
    return request ? (request._redirectCount > 0) : false;
  }

  // Get the source HTML for the last response
  get source() {
    const { response } = this;
    return response ? response.body : null;
  }


  // Debugging
  // ---------

  // Enable debugging.  You can do this in code instead of setting DEBUG environment variable.
  debug() {
    this._debug = Browser._enableDebugging();
  }



  // Zombie can spit out messages to help you figure out what's going on as your code executes.
  //
  // To spit a message to the console when running in debug mode, call this method with one or more values (same as
  // `console.log`).  You can also call it with a function that will be evaluated only when running in debug mode.
  //
  // For example:
  //     browser.log('Opening page:', url);
  //     browser.log(function() { return 'Opening page: ' + url });
  log(...args) {
    if (typeof args[0] === 'function')
      args = [args[0]()];
    this.emit('log', format(...args));
  }

  // Dump information to the console: Zombie version, current URL, history, cookies, event loop, etc.  Useful for
  // debugging and submitting error reports.
  dump(output = process.stdout) {
    function indent(lines) {
      return lines.map(line => `  ${line}\n`).join('');
    }
    output.write(`Zombie: ${Browser.VERSION}\n`);
    output.write(`URL:    ${this.window.location.href}\n`);
    output.write(`\nHistory:\n`);
    this.history.dump(output);
    output.write(`\nCookies:\n`);
    this.cookies.dump(output);
    output.write(`\nStorage:\n`);

    if (this.document) {
      const html  = this.html();
      const slice = (html.length > 497) ? `${html.slice(0, 497)}...` : html;
      output.write(`Document:\n${indent(slice.split('\n'))}\n`);
    } else
      output.write('No document\n');

    output.write('\n');
    this._eventLoop.dump(output);
  }


  // -- Static methods ---

  // ### zombie.visit(url, callback)
  // ### zombie.visit(url, options? callback)
  //
  // Creates a new Browser, opens window to the URL and calls the callback when
  // done processing all events.
  //
  // * url -- URL of page to open
  // * callback -- Called with error, browser
  static visit(url, options, callback) {
    if (arguments.length === 2 && typeof options === 'function')
      [options, callback] = [null, options];
    const browser = new Browser(options);
    if (callback)
      browser.visit(url, (error)=> callback(error, browser));
    else
      return browser.visit(url).then(()=> browser);
  }

  // Allows you to make requests against a named domain and HTTP/S port, and
  // will route it to the test server running on localhost and unprivileged
  // port.
  static localhost(source, target) {
    reroute(source, target);
    if (!this.site) {
      const [ hostname ] = source.split(':');
      this.site = hostname.replace(/^\*\./, '');
    }
  }

  // Register a browser extension.
  //
  // Browser extensions are called for each newly created browser object, and
  // can be used to change browser options, register listeners, add methods,
  // etc.
  static extend(extension) {
    this._extensions.push(extension);
  }

  // Call this to return a debug() instance with debugging enabled.
  static _enableDebugging() {
    // With debugging enabled, every time we call debug('zombie') we get a new
    // instance which outputs with a different color.  This can be confusing, so
    // if debugging is already enabled (DEBUG=zombie) we want to use the current
    // instance.  Otherwise, we want to create a new instance (_debugEnabled)
    // and reuse it every time someone calls browser.debug().
    if (this._debug.enabled)
      return this._debug.enabled;

    if (!this._debugEnabled) {
      debug.enable('zombie');
      this._debugEnabled = debug('zombie');
    }
    return this._debugEnabled;
  }


  // -- Static properties --

  static VERSION  = VERSION

  static Assert   = Assert
  static Pipeline = Pipeline
  static Headers  = Fetch.Headers
  static Request  = Fetch.Request
  static Response = Fetch.Response


  // -- These defaults are used in any new browser instance --

  // Which features are enabled.
  static features = DEFAULT_FEATURES

  // Proxy URL.
  //
  // Example
  //   Browser.proxy = 'http://myproxy:8080'
  static proxy = null

  // If true, suppress `console.log` output from scripts (ignored when DEBUG=zombie)
  static silent = false

  // You can use visit with a path, and it will make a request relative to this host/URL.
  static site = null

  // Check SSL certificates against CA.  False by default since you're likely
  // testing with a self-signed certificate.
  static strictSSL = false

  // Sets the outgoing IP address in case there is more than on available.
  // Defaults to 0.0.0.0 which should select default interface
  static localAddress = '0.0.0.0'

  // User agent string sent to server.
  static userAgent = `Mozilla/5.0 Chrome/10.0.613.0 Safari/534.15 Zombie.js/${VERSION}`

  // Navigator language code
  static language = 'en-US'

  // Default time to wait (visit, wait, etc).
  static waitDuration = '5s'

  // Indicates whether or not to validate and execute JavaScript, default true.
  static runScripts = true


  // -- Internal properties --

  // Debug instance.  Create new instance when enabling debugging with Zombie.debug
  static _debug = debug('zombie')

  // Set after calling _enableDebugging
  static _debugEnabled = null

  // Browser extensions;
  static _extensions = []
}


module.exports = Browser;
