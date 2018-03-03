// Implements XMLHttpRequest.
// See http://www.w3.org/TR/XMLHttpRequest/#the-abort()-method


const DOM     = require('./dom');
const Fetch   = require('./fetch');
const ms      = require('ms');
const URL     = require('url');
const Utils   = require('jsdom/lib/jsdom/utils');
const EventTarget = require('jsdom/lib/jsdom/living/generated/EventTarget');

const { DOMException } = DOM;
const { idlUtils }   = require('./dom/impl');


class XMLHttpRequest {
//class XMLHttpRequest extends EventTarget {

  constructor(window) {
    //super();
    EventTarget.setup(this);
    for (let method in EventTarget.interface.prototype)
      this[method] = EventTarget.interface.prototype[method];

    this._window      = window;
    this._browser     = window.browser;
    // Pending request
    this._pending     = null;
    // Response headers
    this.readyState   = XMLHttpRequest.UNSENT;

    this.onreadystatechange = null;
    this.timeout      = 0;

    // XHR events need the first to dispatch, the second to propagate up to window
    this._ownerDocument = window.document;
    idlUtils.implForWrapper(this)._ownerDocument = this._ownerDocument
  }


  // Aborts the request if it has already been sent.
  abort() {
    const request = this._pending;
    const sent    = !!request;
    if (this.readyState === XMLHttpRequest.UNSENT || (this.readyState === XMLHttpRequest.OPENED && !sent)) {
      this.readyState = XMLHttpRequest.UNSENT;
      return;
    }
    // Aborting a done request sets its readyState to UNSENT and does not trigger a readystatechange event
    // https://xhr.spec.whatwg.org/#the-abort()-method
    if (this.readyState === XMLHttpRequest.DONE) {
      this.readyState = XMLHttpRequest.UNSENT;
    } else {
      // Tell any pending request it has been aborted.
      request.aborted = true;
    }
    this._response  = null;
    this._error     = null;
    this._pending   = null;
  }


  // Initializes a request.
  //
  // Calling this method an already active request (one for which open()or
  // openRequest()has already been called) is the equivalent of calling abort().
  open(method, url, useAsync, user, password) { // jshint ignore:line
    if (useAsync === false)
      throw new DOMException(DOMException.NOT_SUPPORTED_ERR, 'Zombie does not support synchronous XHR requests');

    // Abort any pending request.
    this.abort();

    // Check supported HTTP method
    this._method = method.toUpperCase();
    if (/^(CONNECT|TRACE|TRACK)$/.test(this._method))
      throw new DOMException(DOMException.SECURITY_ERR, 'Unsupported HTTP method');
    if (!/^(DELETE|GET|HEAD|OPTIONS|POST|PUT)$/.test(this._method))
      throw new DOMException(DOMException.SYNTAX_ERR, 'Unsupported HTTP method');

    const headers = new Fetch.Headers();

    // Normalize the URL and check security
    url = URL.parse(URL.resolve(this._window.location.href, url));
    // Don't consider port if they are standard for http and https
    if ((url.protocol === 'https:' && url.port === '443') ||
        (url.protocol === 'http:'  && url.port === '80'))
      delete url.port;

    if (!/^https?:$/i.test(url.protocol))
      throw new DOMException(DOMException.NOT_SUPPORTED_ERR, 'Only HTTP/S protocol supported');
    url.hostname = url.hostname || this._window.location.hostname;
    url.host = url.port ? `${url.hostname}:${url.port}` : url.hostname;
    if (url.host !== this._window.location.host) {
      headers.set('Origin', `${this._window.location.protocol}//${this._window.location.host}`);
      this._cors = headers.get('Origin');
    }
    url.hash = null;
    if (user)
      url.auth = `${user}:${password}`;
    // Used for logging requests
    this._url       = URL.format(url);
    this._headers   = headers;

    // Reset response status
    this._stateChanged(XMLHttpRequest.OPENED);
  }


  // Sets the value of an HTTP request header.You must call setRequestHeader()
  // after open(), but before send().
  setRequestHeader(header, value) {
    if (this.readyState !== XMLHttpRequest.OPENED)
      throw new DOMException(DOMException.INVALID_STATE_ERR,  'Invalid state');
    this._headers.set(header, value);
  }


  // Sends the request. If the request is asynchronous (which is the default),
  // this method returns as soon as the request is sent. If the request is
  // synchronous, this method doesn't return until the response has arrived.
  send(data) {
    // Request must be opened.
    if (this.readyState !== XMLHttpRequest.OPENED)
      throw new DOMException(DOMException.INVALID_STATE_ERR,  'Invalid state');

    const request = new Fetch.Request(this._url, {
      method:   this._method,
      headers:  this._headers,
      body:     data
    });
    this._pending = request;
    this._fire('loadstart');

    const timeout = setTimeout(()=> {
      if (this._pending === request)
        this._pending = null;
      request.timedOut = true;

      this._stateChanged(XMLHttpRequest.DONE);
      this._fire('progress');
      this._error = new DOMException(DOMException.TIMEOUT_ERR, 'The request timed out');
      this._fire('timeout', this._error);
      this._fire('loadend');
      this._browser.errors.push(this._error);
    }, this.timeout || ms('2m'));

    this._window._eventQueue.http(request, (error, response)=> {
      // Request already timed-out, nothing to do
      if (request.timedOut)
        return;
      clearTimeout(timeout);

      if (this._pending === request)
        this._pending = null;

      // Request aborted
      if (request.aborted) {
        this._stateChanged(XMLHttpRequest.DONE);
        this._fire('progress');
        this._error = new DOMException(DOMException.ABORT_ERR, 'Request aborted');
        this._fire('abort', this._error);
        return;
      }

      // If not aborted, then we look at networking error
      if (error) {
        this._stateChanged(XMLHttpRequest.DONE);
        this._fire('progress');
        this._error = new DOMException(DOMException.NETWORK_ERR);
        this._fire('error', this._error);
        this._fire('loadend');
        this._browser.errors.push(this._error);
        return;
      }

      // CORS request, check origin, may lead to new error
      if (this._cors) {
        const allowedOrigin = response.headers.get('Access-Control-Allow-Origin');
        if (!(allowedOrigin === '*' || allowedOrigin === this._cors)) {
          this._error = new DOMException(DOMException.SECURITY_ERR, 'Cannot make request to different domain');
          this._browser.errors.push(this._error);
          this._stateChanged(XMLHttpRequest.DONE);
          this._fire('progress');
          this._fire('error', this._error);
          this._fire('loadend');
          this.raise('error', this._error.message, { exception: this._error });
          return;
        }
      }

      // Store the response so getters have acess access it
      this._response        = response;
      // We have a one-stop implementation that goes through all the state
      // transitions
      this._stateChanged(XMLHttpRequest.HEADERS_RECEIVED);
      this._stateChanged(XMLHttpRequest.LOADING);

      const done = this._window._eventQueue.waitForCompletion();
      response.text().then(text => {
        this.responseText = text;
        this._stateChanged(XMLHttpRequest.DONE);

        this._fire('progress');
        this._fire('load');
        this._fire('loadend');
        done();
      });


    });
    request.sent = true;
  }


  get status() {
    // Status code/headers available immediately, 0 if request errored
    return this._response ? this._response.status :
           this._error    ? 0 : null;
  }

  get statusText() {
    // Status code/headers available immediately, '' if request errored
    return this._response ? this._response.statusText :
           this._error    ? '' : null;
  }

  get responseXML() {
    // Not implemented yet
    return null;
  }

  getResponseHeader(name) {
    // Returns the string containing the text of the specified header, or null if
    // either the response has not yet been received or the header doesn't exist in
    // the response.
    return this._response && this._response.headers.get(name) || null;
  }

  getAllResponseHeaders() {
    // Returns all the response headers as a string, or null if no response has
    // been received. Note: For multipart requests, this returns the headers from
    // the current part of the request, not from the original channel.
    if (this._response)
      // XHR's getAllResponseHeaders, against all reason, returns a multi-line
      // string.  See http://www.w3.org/TR/XMLHttpRequest/#the-getallresponseheaders-method
      return this._response.headers.toString();
    else
      return null;
  }


  // Fire onreadystatechange event
  _stateChanged(newState) {
    this.readyState = newState;
    this._fire('readystatechange');
  }

  // Fire the named event on this object
  _fire(eventName, error) {
    const event = new DOM.Event('xhr');
    event.initEvent(eventName, true, true);
    event.error = error;
    this._dispatchEvent(event);
    this._browser.emit('xhr', eventName, this._url);
  }

  // Raise error coming from jsdom
  raise(type, message, data) {
    this._ownerDocument.raise(type, message, data);
  }

  _dispatchEvent(event) {
    const listener = this[`on${event.type}`];
    if (listener)
      this[idlUtils.implSymbol]._eventListeners[event.type] = [{
        callback: listener,
        options: {}
      }];
    this.dispatchEvent(event);
  }

}


// Lifecycle states
XMLHttpRequest.UNSENT           = 0;
XMLHttpRequest.OPENED           = 1;
XMLHttpRequest.HEADERS_RECEIVED = 2;
XMLHttpRequest.LOADING          = 3;
XMLHttpRequest.DONE             = 4;

module.exports = XMLHttpRequest;
