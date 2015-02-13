// Implemenets XMLHttpRequest.
// See http://www.w3.org/TR/XMLHttpRequest/#the-abort()-method


const DOM   = require('./dom');
const URL   = require('url');


class XMLHttpRequest extends DOM.EventTarget {

  constructor(window) {
    this._window      = window;
    // Pending request
    this._pending     = null;
    // Response headers
    this._responseHeaders = null;
    this.readyState   = XMLHttpRequest.UNSENT;

    this.onreadystatechange = null;
    this.timeout      = 0;
    this.status       = null;
    this.statusText   = null;
    this.responseText = null;
    this.responseXML  = null;

    // XHR events need the first to dispatch, the second to propagate up to window
    this._ownerDocument = window.document;
  }


  // Aborts the request if it has already been sent.
  abort() {
    // Tell any pending request it has been aborted.
    const request = this._pending;
    if (this.readyState === XMLHttpRequest.UNSENT || (this.readyState === XMLHttpRequest.OPENED && !request.sent)) {
      this.readyState = XMLHttpRequest.UNSENT;
      return;
    }

    // Tell any pending request it has been aborted.
    request.aborted = true;
  }


  // Returns all the response headers as a string, or null if no response has
  // been received. Note: For multipart requests, this returns the headers from
  // the current part of the request, not from the original channel.
  getAllResponseHeaders(header) {
    if (this._responseHeaders) {
      // XHR's getAllResponseHeaders, against all reason, returns a multi-line
      // string.  See http://www.w3.org/TR/XMLHttpRequest/#the-getallresponseheaders-method
      const headerStrings = [];
      for (let name in this._responseHeaders) {
        let value = this._responseHeaders[name];
        headerStrings.push(`${name}: ${value}`);
      }
      return headerStrings.join('\n');
    } else
      return null;
  }


  // Returns the string containing the text of the specified header, or null if
  // either the response has not yet been received or the header doesn't exist in
  // the response.
  getResponseHeader(header) {
    if (this._responseHeaders)
      return this._responseHeaders[header.toLowerCase()];
    else
      return null;
  }


  // Initializes a request.
  //
  // Calling this method an already active request (one for which open()or
  // openRequest()has already been called) is the equivalent of calling abort().
  open(method, url, useAsync, user, password) { // jshint ignore:line
    if (useAsync === false)
      throw new DOM.DOMException(DOM.NOT_SUPPORTED_ERR, 'Zombie does not support synchronous XHR requests');

    // Abort any pending request.
    this.abort();

    // Check supported HTTP method
    method = method.toUpperCase();
    if (/^(CONNECT|TRACE|TRACK)$/.test(method))
      throw new DOM.DOMException(DOM.SECURITY_ERR, 'Unsupported HTTP method');
    if (!/^(DELETE|GET|HEAD|OPTIONS|POST|PUT)$/.test(method))
      throw new DOM.DOMException(DOM.SYNTAX_ERR, 'Unsupported HTTP method');

    const headers = {};

    // Normalize the URL and check security
    url = URL.parse(URL.resolve(this._window.location.href, url));
    // Don't consider port if they are standard for http and https
    if ((url.protocol === 'https:' && url.port === '443') ||
        (url.protocol === 'http:'  && url.port === '80'))
      delete url.port;

    if (!/^https?:$/i.test(url.protocol))
      throw new DOM.DOMException(DOM.NOT_SUPPORTED_ERR, 'Only HTTP/S protocol supported');
    url.hostname = url.hostname || this._window.location.hostname;
    url.host = url.port ? `${url.hostname}:${url.port}` : url.hostname;
    if (url.host !== this._window.location.host) {
      headers.origin = `${this._window.location.protocol}//${this._window.location.host}`;
      this._cors = headers.origin;
    }
    url.hash = null;
    if (user)
      url.auth = `${user}:${password}`;

    // Reset all the response fields.
    this.status       = null;
    this.statusText   = null;
    this.responseText = null;
    this.responseXML  = null;

    const request = { method, headers, url: URL.format(url) };
    this._pending = request;
    this._stateChanged(XMLHttpRequest.OPENED);
  }

  // Sends the request. If the request is asynchronous (which is the default),
  // this method returns as soon as the request is sent. If the request is
  // synchronous, this method doesn't return until the response has arrived.
  send(data) {
    // Request must be opened.
    if (this.readyState !== XMLHttpRequest.OPENED)
      throw new DOM.DOMException(DOM.INVALID_STATE_ERR,  'Invalid state');

    this._fire('loadstart');

    const request   = this._pending;
    request.headers['content-type'] = request.headers['content-type'] || 'text/plain';
    // Make the actual request
    request.body    = data;
    request.timeout = this.timeout;

    this._window._eventQueue.http(request.method, request.url, request, (error, response)=> {
      if (this._pending === request)
        this._pending = null;

      // If aborting or error
      this.status       = 0;
      this.responseText = '';

      // Request aborted
      if (request.aborted) {
        this._stateChanged(XMLHttpRequest.DONE);
        this._fire('progress');
        this._fire('abort', new DOM.DOMException(DOM.ABORT_ERR, 'Request aborted'));
        return;
      }

      if (error) {
        this._stateChanged(XMLHttpRequest.DONE);
        this._fire('progress');
        if (error.code === 'ETIMEDOUT')
          this._fire('timeout', new DOM.DOMException(DOM.TIMEOUT_ERR, 'The request timed out'));
        else
          this._fire('error', new DOM.DOMException(DOM.NETWORK_ERR, error.message));
        this._fire('loadend');
        return;
      }

      // CORS request, check origin, may lead to new error
      if (this._cors) {
        const allowedOrigin = response.headers['access-control-allow-origin'];
        if (!(allowedOrigin === '*' || allowedOrigin === this._cors)) {
          const corsError = new DOM.DOMException(DOM.SECURITY_ERR, 'Cannot make request to different domain');
          this._stateChanged(XMLHttpRequest.DONE);
          this._fire('progress');
          this._fire('error', corsError);
          this._fire('loadend');
          this.raise('error', corsError.message, { exception: corsError });
          return;
        }
      }

      // Since the request was not aborted, we set all the fields here and change
      // the state to HEADERS_RECEIVED.
      this.status           = response.statusCode;
      this.statusText       = response.statusText;
      this._responseHeaders = response.headers;
      this._stateChanged(XMLHttpRequest.HEADERS_RECEIVED);

      this.responseText = response.body ? response.body.toString() : '';
      this._stateChanged(XMLHttpRequest.LOADING);

      this.responseXML = null;
      this._stateChanged(XMLHttpRequest.DONE);

      this._fire('progress');
      this._fire('load');
      this._fire('loadend');

    });
    request.sent = true;
  }


  // Sets the value of an HTTP request header.You must call setRequestHeader()
  // after open(), but before send().
  setRequestHeader(header, value) {
    if (this.readyState !== XMLHttpRequest.OPENED)
      throw new DOM.DOMException(DOM.INVALID_STATE_ERR,  'Invalid state');
    const request = this._pending;
    request.headers[header.toString().toLowerCase()] = value.toString();
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
    this.dispatchEvent(event);
  }

  // Raise error coming from jsdom
  raise(type, message, data) {
    this._ownerDocument.raise(type, message, data);
  }

}


// Lifecycle states
XMLHttpRequest.UNSENT           = 0;
XMLHttpRequest.OPENED           = 1;
XMLHttpRequest.HEADERS_RECEIVED = 2;
XMLHttpRequest.LOADING          = 3;
XMLHttpRequest.DONE             = 4;

module.exports = XMLHttpRequest;

