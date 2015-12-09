const _               = require('lodash');
const assert          = require('assert');
const Bluebird        = require('bluebird');
const Fetch           = require('./fetch');
const File            = require('fs');
const { Headers }     = require('./fetch');
const { isArray }     = require('util');
const Path            = require('path');
const Request         = require('request');
const resourceLoader  = require('jsdom/lib/jsdom/browser/resource-loader');
const URL             = require('url');
const Utils           = require('jsdom/lib/jsdom/utils');


// Pipeline is sequence of request/response handlers that are used to prepare a
// request, make the request, and process the response.
class Pipeline extends Array {

  constructor(browser) {
    super();
    this._browser = browser;
    for (let handler of Pipeline._default)
      this.push(handler);
  }

  _fetch(input, init) {
    const request   = new Fetch.Request(input, init);
    const browser   = this._browser;
    browser.emit('request', request);

    return this
      ._runPipeline(request)
      .then(function(response) {
        response.time     = Date.now();
        response.request  = request;
        browser.emit('response', request, response);
        return response;
      })
      .catch(function(error) {
        browser._debug('Resource error', error.stack);
        throw new TypeError(error.message);
      });
  }

  _runPipeline(request) {
    return this
      ._getOriginalResponse(request)
      .then((response)=> {
        return this._prepareResponse(request, response);
      });
  }

  _getOriginalResponse(request) {
    const browser         = this._browser;
    const requestHandlers = this.filter(fn => fn.length === 2).concat(Pipeline.makeHTTPRequest);

    return Bluebird.reduce(requestHandlers, function(lastResponse, requestHandler) {
        return lastResponse || requestHandler(browser, request);
      }, null)
      .then(function(response) {
        assert(response && response.hasOwnProperty('statusText'), 'Request handler must return a response');
        return response;
      });
  }

  _prepareResponse(request, originalResponse) {
    const browser           = this._browser;
    const responseHandlers  = this.filter(fn => fn.length === 3);

    return Bluebird.reduce(responseHandlers, function(lastResponse, responseHandler) {
        return responseHandler(browser, request, lastResponse);
      }, originalResponse)
      .then(function(response) {
        assert(response && response.hasOwnProperty('statusText'), 'Response handler must return a response');
        return response;
      });
  }


  // -- Handlers --

  // Add a request or response handler.  This handler will only be used by this
  // pipeline instance (browser).
  addHandler(handler) {
    assert(handler.call, 'Handler must be a function');
    assert(handler.length === 2 || handler.length === 3, 'Handler function takes 2 (request handler) or 3 (reponse handler) arguments');
    this.push(handler);
  }

  // Remove a request or response handler.
  removeHandler(handler) {
    assert(handler.call, 'Handler must be a function');
    var index = this.indexOf(handler);
    if (index > -1) {
        delete this[index];
    }
  }

  // Add a request or response handler.  This handler will be used by any new
  // pipeline instance (browser).
  static addHandler(handler) {
    assert(handler.call, 'Handler must be a function');
    assert(handler.length === 2 || handler.length === 3, 'Handler function takes 2 (request handler) or 3 (response handler) arguments');
    this._default.push(handler);
  }
  
  // Remove a request or response handler.
  static removeHandler(handler) {
    assert(handler.call, 'Handler must be a function');
    var index = this._default.indexOf(handler);
    if (index > -1) {
        delete this._default[index];
    }
  }


  // -- Prepare request --

  // This handler normalizes the request URL.
  //
  // It turns relative URLs into absolute URLs based on the current document URL
  // or base element, or if no document open, based on browser.site property.
  static normalizeURL(browser, request) {
    if (browser.document)
    // Resolve URL relative to document URL/base, or for new browser, using
    // Browser.site
      request.url = resourceLoader.resolveResourceUrl(browser.document, request.url);
    else
      request.url = Utils.resolveHref(browser.site || 'http://localhost', request.url);
  }


  // This handler mergers request headers.
  //
  // It combines headers provided in the request with custom headers defined by
  // the browser (user agent, authentication, etc).
  //
  // It also normalizes all headers by down-casing the header names.
  static mergeHeaders(browser, request) {
    if (browser.headers)
      _.each(browser.headers, (value, name)=> {
        request.headers.append(name, browser.headers[name]);
      });
    if (!request.headers.has('User-Agent'))
      request.headers.set('User-Agent', browser.userAgent);

    // Always pass Host: from request URL
    const { host } = URL.parse(request.url);
    request.headers.set('Host', host);

    // HTTP Basic authentication
    const authenticate = { host, username: null, password: null };
    browser.emit('authenticate', authenticate);
    const { username, password } = authenticate;
    if (username && password) {
      browser.log(`Authenticating as ${username}:${password}`);
      const base64 = new Buffer(`${username}:${password}`).toString('base64');
      request.headers.set('authorization',  `Basic ${base64}`);
    }
  }


  // -- Retrieve actual resource --

  // Used to perform HTTP request (also supports file: resources).  This is always
  // the last request handler.
  static makeHTTPRequest(browser, request) {
    const { url } = request;
    const { protocol, hostname, pathname } = URL.parse(url);

    if (protocol === 'file:') {

      // If the request is for a file:// descriptor, just open directly from the
      // file system rather than getting node's http (which handles file://
      // poorly) involved.
      if (request.method !== 'GET')
        return new Fetch.Response('', { url, status: 405 });

      const filename = Path.normalize(decodeURI(pathname));
      const exists   = File.existsSync(filename);
      if (exists) {
        const stream = File.createReadStream(filename);
        return new Fetch.Response(stream, { url, status: 200 });
      } else
        return new Fetch.Response('', { url, status: 404 });

    }

    // We're going to use cookies later when receiving response.
    const { cookies }   = browser;
    const cookieHeader  = cookies.serialize(hostname, pathname);
    if (cookieHeader)
      request.headers.append('Cookie', cookieHeader);

    const consumeBody = /^POST|PUT/.test(request.method) && request._consume() || Promise.resolve(null);
    return consumeBody
      .then(function(body) {

        const httpRequest = new Request({
          method:         request.method,
          uri:            request.url,
          headers:        request.headers.toObject(),
          proxy:          browser.proxy,
          body,
          jar:            false,
          followRedirect: false,
          strictSSL:      browser.strictSSL,
          localAddress:   browser.localAddress || 0
        });

        return new Promise(function(resolve, reject) {
          httpRequest
            .on('response', (response)=> {
              // Request returns an object where property name is header name,
              // property value is either header value, or an array if header sent
              // multiple times (e.g. `Set-Cookie`).
              const arrayOfHeaders = _.reduce(response.headers, (headers, value, name)=> {
                if (isArray(value))
                  for (let item of value)
                    headers.push([name, item]);
                else
                  headers.push([name, value]);
                return headers;
              }, []);

              resolve(new Fetch.Response(response, {
                url:        request.url,
                status:     response.statusCode,
                headers:    new Headers(arrayOfHeaders)
              }));
            })
            .on('error', reject);
        });

      });
  }


  // -- Handle response --

  static handleHeaders(browser, request, response) {
    response.headers = new Headers(response.headers);
    return response;
  }

  static handleCookies(browser, request, response) {
    // Set cookies from response: call update() with array of headers
    const { hostname, pathname } = URL.parse(request.url);
    const newCookies = response.headers.getAll('Set-Cookie');
    browser.cookies.update(newCookies, hostname, pathname);
    return response;
  }

  static handleRedirect(browser, request, response) {
    const { status }  = response;
    if (status === 301 || status === 302 || status === 303 || status === 307 || status === 308) {
      if (request.redirect === 'error')
        return Fetch.Response.error();

      const location = response.headers.get('Location');
      if (location === null)
        return response;

      if (request._redirectCount >= 20)
        return Fetch.Response.error();

      browser.emit('redirect', request, response, location);
      ++request._redirectCount;
      if (status !== 307) {
        request.method = 'GET';
        request.headers.delete('Content-Type');
        request.headers.delete('Content-Length');
        request.headers.delete('Content-Transfer-Encoding');
      }

      // This request is referer for next
      request.headers.set('Referer', request.url);
      request.url = Utils.resolveHref(request.url, location);
      return browser.pipeline._runPipeline(request);
    } else
      return response;
  }

}


// The default pipeline.  All new pipelines are instantiated with this set of
// handlers.
Pipeline._default = [
  Pipeline.normalizeURL,
  Pipeline.mergeHeaders,
  Pipeline.handleHeaders,
  Pipeline.handleCookies,
  Pipeline.handleRedirect
];

module.exports = Pipeline;

