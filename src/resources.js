// Resource history and resource pipeline.


const _           = require('lodash');
const assert      = require('assert');
const DOM         = require('./dom');
const File        = require('fs');
const Fetch       = require('./fetch');
const { Headers } = require('./fetch');
const { isArray } = require('util');
const Path        = require('path');
const QS          = require('querystring');
const Request     = require('request');
const URL         = require('url');
const Utils       = require('jsdom/lib/jsdom/utils');



function formData(name, value) {
  if (value.read) {
    const buffer = value.read();
    return {
      'Content-Disposition':  `form-data; name=\"${name}\"; filename=\"${value}\"`,
      'Content-Type':         value.mime || 'application/octet-stream',
      'Content-Length':       buffer.length,
      body:                   buffer
    };
  } else
    return {
      'Content-Disposition':  `form-data; name=\"${name}\"`,
      'Content-Type':         'text/plain; charset=utf8',
      'Content-Length':       value.length,
      body:                   value
    };
}


class Resource {

  constructor({ request, target }) {
    this.request  = request;
    this.target   = target;
    this.error    = null;
    this.response = null;
  }

  get url() {
    return (this.response && this.response.url) || this.request.url;
  }

  dump(output) {
    const { request, response, error, target } = this;
    // Write summary request/response header
    if (response) {
      const elapsed = response.time - request.time;
      output.write(`${request.method} ${this.url} - ${response.status} ${response.statusText} - ${elapsed}ms\n`);
    } else
      output.write(`${request.method} ${this.url}\n`);

    // Tell us which element/document is loading this.
    if (target instanceof DOM.Document)
      output.write('  Loaded as HTML document\n');
    else if (target && target.id)
      output.write(`  Loading by element #${target.id}\n`);
    else if (target)
      output.write(`  Loading as ${target.tagName} element\n`);

    // If response, write out response headers and sample of document entity
    // If error, write out the error message
    // Otherwise, indicate this is a pending request
    if (response) {
      if (response.redirects)
        output.write(`  Followed ${response.redirects} redirects\n`);
      for (let [name, value] of response.headers)
        output.write(`  ${name}: ${value}\n`);
      output.write('\n');
      const sample = response.body
        .slice(0, 250)
        .toString('utf8')
        .split('\n')
        .map(line => `  ${line}`)
        .join('\n');
      output.write(sample);
    } else if (error)
      output.write(`  Error: ${error.message}\n`);
    else
      output.write(`  Pending since ${new Date(request.time)}\n`);
    // Keep them separated
    output.write('\n\n');
  }

}


// Each browser has a resources object that provides the means for retrieving
// resources and a list of all retrieved resources.
//
// The object is an array, and its elements are the resources.
class Resources extends Array {

  constructor(browser) {
    this.browser  = browser;
    this.pipeline = Resources.pipeline.slice();
  }


  // Make an HTTP request (also supports file: protocol).
  //
  // method    - Request method (GET, POST, etc)
  // url       - Request URL
  // options   - See below
  //
  // Options:
  //   headers   - Name/value pairs of headers to send in request
  //   params    - Parameters to pass in query string or document body
  //   body      - Request document body
  //   timeout   - Request timeout in milliseconds (0 or null for no timeout)
  async request(method, url, options = {}) {
    const req = {
      method:       method.toUpperCase(),
      url:          url,
      headers:      new Headers(options.headers),
      params:       options.params,
      body:         options.body,
      time:         Date.now(),
      timeout:      options.timeout || 0,
      strictSSL:    this.browser.strictSSL,
      localAddress: this.browser.localAddress || 0
    };

    const resource = new Resource({
      request:    req,
      target:     options.target
    });
    this.push(resource);
    this.browser.emit('request', req);

    try {
      const response    = await this._runPipeline(req);
      response.time     = Date.now();
      resource.response = response;
      this.browser.emit('response', req, response);
    } catch (error) {
      this.browser._debug('Resource error', error.stack);
      resource.error    = error;
      resource.response = Fetch.Response.error();
    }
    return resource.response;
  }


  // GET request.
  //
  // url       - Request URL
  // options   - See request() method
  async get(url, options) {
    return await this.request('get', url, options);
  }

  // POST request.
  //
  // url       - Request URL
  // options   - See request() method
  async post(url, options) {
    return await this.request('post', url, options);
  }


  // Human readable resource listing.
  //
  // output - Write to this stream (optional)
  dump(output = process.stdout) {
    if (this.length === 0)
      output.write('No resources\n');
    else
      this.forEach(resource => resource.dump(output));
  }

  // Add a request/response handler.  This handler will only be used by this
  // browser.
  addHandler(handler) {
    assert(handler.call, 'Handler must be a function');
    assert(handler.length === 2 || handler.length === 3, 'Handler function takes 2 (request handler) or 3 (reponse handler) arguments');
    this.pipeline.push(handler);
  }

  // Processes the request using the pipeline.
  async _runPipeline(request) {
    const { browser } = this;
    const requestHandlers   = this.pipeline.filter(fn => fn.length === 2).concat(Resources.makeHTTPRequest);
    const responseHandlers  = this.pipeline.filter(fn => fn.length === 3);

    let response;
    for (let requestHandler of requestHandlers) {
      response = await requestHandler(browser, request);
      if (response)
        break;
    }
    for (let responseHandler of responseHandlers)
      response = await responseHandler(browser, request, response);
    return response;
  }


  // -- Handlers --

  static addHandler(handler) {
    assert(handler.call, 'Handler must be a function');
    assert(handler.length === 2 || handler.length === 3, 'Handler function takes 2 (request handler) or 3 (response handler) arguments');
    this.pipeline.push(handler);
  }


  // This handler normalizes the request URL.
  //
  // It turns relative URLs into absolute URLs based on the current document URL
  // or base element, or if no document open, based on browser.site property.
  //
  // Also creates query string from request.params for
  // GET/HEAD/DELETE requests.
  static normalizeURL(browser, req) {
    if (browser.document)
    // Resolve URL relative to document URL/base, or for new browser, using
    // Browser.site
      req.url = DOM.resourceLoader.resolve(browser.document, req.url);
    else
      req.url = Utils.resolveHref(browser.site || 'http://localhost', req.url);

    if (req.params) {
      const { method } = req;
      if (method === 'GET' || method === 'HEAD' || method === 'DELETE') {
        // These methods use query string parameters instead
        const uri = URL.parse(req.url, true);
        Object.assign(uri.query, req.params);
        req.url = URL.format(uri);
      }
    }
  }


  // This handler mergers request headers.
  //
  // It combines headers provided in the request with custom headers defined by
  // the browser (user agent, authentication, etc).
  //
  // It also normalizes all headers by down-casing the header names.
  static mergeHeaders(browser, req) {
    if (browser.headers)
      _.each(browser.headers, (value, name)=> {
        req.headers.append(name, browser.headers[name]);
      });
    if (!req.headers.has('User-Agent'))
      req.headers.set('User-Agent', browser.userAgent);

    // Always pass Host: from request URL
    const { host } = URL.parse(req.url);
    req.headers.set('Host', host);

    // HTTP Basic authentication
    const authenticate = { host, username: null, password: null };
    browser.emit('authenticate', authenticate);
    const { username, password } = authenticate;
    if (username && password) {
      browser.log(`Authenticating as ${username}:${password}`);
      const base64 = new Buffer(`${username}:${password}`).toString('base64');
      req.headers.set('authorization',  `Basic ${base64}`);
    }
  }


  // Depending on the content type, this handler will create a request body from
  // request.params, set request.multipart for uploads.
  static createBody(browser, req) {
    const { method } = req;
    if (method !== 'POST' && method !== 'PUT')
      return;

    const { headers } = req;
    // These methods support document body.  Create body or multipart.
    headers.set('content-type', headers.get('content-type') || 'application/x-www-form-urlencoded');
    const mimeType = headers.get('content-type').split(';')[0];
    if (req.body)
      return;

    const params = req.params || {};
    switch (mimeType) {
      case 'application/x-www-form-urlencoded': {
        req.body = QS.stringify(params);
        headers.set('content-length', req.body.length);
        break;
      }

      case 'multipart/form-data': {
        if (Object.keys(params).length === 0) {
          // Empty parameters, can't use multipart
          headers.set('content-type', 'text/plain');
          req.body = '';
        } else {

          const boundary = `${new Date().getTime()}.${Math.random()}`;
          const withBoundary = headers.get('content-type') + `; boundary=${boundary}`;
          headers.set('content-type', withBoundary);
          req.multipart = Object.keys(params)
            .reduce((parts, name)=> {
              const values = params[name]
                .map(value => formData(name, value) );
              return parts.concat(values);
            }, []);
        }
        break;
      }

      case 'text/plain': {
        // XHR requests use this by default
        break;
      }

      default: {
        throw new Error(`Unsupported content type ${mimeType}`);
      }
    }
  }


  // Used to perform HTTP request (also supports file: resources).  This is always
  // the last request handler.
  static async makeHTTPRequest(browser, req) {
    const { url } = req;
    const { protocol, hostname, pathname } = URL.parse(url);

    if (protocol === 'file:') {

      // If the request is for a file:// descriptor, just open directly from the
      // file system rather than getting node's http (which handles file://
      // poorly) involved.
      if (req.method !== 'GET')
        return new Fetch.Response('', { url, status: 405 });

      const filename = Path.normalize(decodeURI(pathname));
      const exists   = File.existsSync(filename);
      if (exists) {
        const stream = File.createReadStream(filename);
        return new Fetch.Response(stream, { url, status: 200 });
      } else
        return new Fetch.Response('', { url, status: 404 });

    } else {

      // We're going to use cookies later when recieving response.
      const { cookies } = browser;
      req.headers.append('Cookie', cookies.serialize(hostname, pathname));

      const request = new Request({
        method:         req.method,
        uri:            req.url,
        headers:        req.headers.toObject(),
        body:           req.body,
        multipart:      req.multipart,
        proxy:          browser.proxy,
        jar:            false,
        followRedirect: false,
        encoding:       null,
        strictSSL:      req.strictSSL,
        localAddress:   req.localAddress || 0,
        timeout:        req.timeout || 0
      });
      return new Promise(function(resolve, reject) {
        request.on('response', (response)=> {
          request.pause();

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
            url:        req.url,
            status:     response.statusCode,
            headers:    new Headers(arrayOfHeaders),
            redirects:  req.redirects || 0
          }));
        });
        request.on('error', reject);
      });
    }

  }


  static handleHeaders(browser, req, res) {
    res.headers = new Headers(res.headers);
    return res;
  }

  static handleCookies(browser, req, res) {
    // Set cookies from response: call update() with array of headers
    const { hostname, pathname } = URL.parse(req.url);
    const newCookies = res.headers.getAll('Set-Cookie');
    browser.cookies.update(newCookies, hostname, pathname);
    return res;
  }


  static handleRedirect(browser, req, res) {
    // Determine whether to automatically redirect and which method to use
    // based on the status code
    const { status }  = res;
    let redirectUrl   = null;
    if ((status === 301 || status === 307) &&
        (req.method === 'GET' || req.method === 'HEAD'))
      // Do not follow POST redirects automatically, only GET/HEAD
      redirectUrl = Utils.resolveHref(req.url, res.headers.get('Location') || '');
    else if (status === 302 || status === 303)
      // Follow redirect using GET (e.g. after form submission)
      redirectUrl = Utils.resolveHref(req.url, res.headers.get('Location') || '');

    if (redirectUrl) {

      // Handle redirection, make sure we're not caught in an infinite loop
      if (res.redirects >= browser.maxRedirects)
        throw new Error(`More than ${browser.maxRedirects} redirects, giving up`);

      const redirectHeaders = new Headers(req.headers);
      // This request is referer for next
      redirectHeaders.set('Referer', req.url);
      // These headers exist in POST request, do not pass to redirect (GET)
      redirectHeaders.delete('Content-Type');
      redirectHeaders.delete('Content-Length');
      redirectHeaders.delete('Content-Transfer-Encoding');
      // Redirect must follow the entire chain of handlers.
      const redirectRequest = {
        method:     'GET',
        url:        redirectUrl,
        headers:    redirectHeaders,
        redirects:  res.redirects + 1,
        strictSSL:  req.strictSSL,
        time:       req.time,
        timeout:    req.timeout
      };
      browser.emit('redirect', req, res, redirectRequest);
      return browser.resources._runPipeline(redirectRequest);

    } else
      return res;
  }


}


// All browsers start out with this list of handler.
Resources.pipeline = [
  Resources.normalizeURL,
  Resources.mergeHeaders,
  Resources.createBody,
  Resources.handleHeaders,
  Resources.handleCookies,
  Resources.handleRedirect
];


module.exports = Resources;

