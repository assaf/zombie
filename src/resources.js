// Resource history and resource pipeline.


const _           = require('lodash');
const assert      = require('assert');
const DOM         = require('./dom');
const File        = require('fs');
const Fetch       = require('./fetch');
const { Headers } = require('./fetch');
const { isArray } = require('util');
const Path        = require('path');
const Request     = require('request');
const URL         = require('url');
const Utils       = require('jsdom/lib/jsdom/utils');


class Resource {

  constructor({ request }) {
    this.request  = request;
    this.error    = null;
    this.response = null;
  }

  get url() {
    return (this.response && this.response.url) || this.request.url;
  }

  dump(output) {
    const { request, response, error } = this;
    // Write summary request/response header
    if (response) {
      const elapsed = response.time - request.time;
      output.write(`${request.method} ${this.url} - ${response.status} ${response.statusText} - ${elapsed}ms\n`);
    } else
      output.write(`${request.method} ${this.url}\n`);

    // If response, write out response headers and sample of document entity
    // If error, write out the error message
    // Otherwise, indicate this is a pending request
    if (response) {
      if (response._redirectCount)
        output.write(`  Followed ${response._redirectCount} redirects\n`);
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


  async fetch(input, init) {
    const request   = new Fetch.Request(input, init);
    const resource  = new Resource({ request });
    this.push(resource);
    this.browser.emit('request', request);

    try {
      const response = await this._runPipeline(request);
      if (response) {
        response.time     = Date.now();
        response.request  = request;
        resource.response = response;
        this.browser.emit('response', request, response);
        return response;
      } else {
        resource.response = Fetch.Resource.error();
        throw new TypeError('No response');
      }
    } catch (error) {
      this.browser._debug('Resource error', error.stack);
      resource.error    = error;
      resource.response = Fetch.Response.error();
      throw new TypeError(error.message);
    }
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
  static normalizeURL(browser, request) {
    if (browser.document)
    // Resolve URL relative to document URL/base, or for new browser, using
    // Browser.site
      request.url = DOM.resourceLoader.resolve(browser.document, request.url);
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


  // Used to perform HTTP request (also supports file: resources).  This is always
  // the last request handler.
  static async makeHTTPRequest(browser, request) {
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

    } else {

      // We're going to use cookies later when recieving response.
      const { cookies }   = browser;
      const cookieHeader  = cookies.serialize(hostname, pathname);
      if (cookieHeader)
        request.headers.append('Cookie', cookieHeader);

      const buffer      = /^GET|HEAD$/.test(request.method) ? null : await request._consume();
      const httpRequest = new Request({
        method:         request.method,
        uri:            request.url,
        headers:        request.headers.toObject(),
        proxy:          browser.proxy,
        body:           buffer,
        jar:            false,
        followRedirect: false,
        strictSSL:      browser.strictSSL,
        localAddress:   browser.localAddress || 0
      });
      return await new Promise(function(resolve, reject) {
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
    }

  }


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


  static async handleRedirect(browser, request, response) {
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
      return await browser.resources._runPipeline(request);
    } else
      return response;
  }


}


// All browsers start out with this list of handler.
Resources.pipeline = [
  Resources.normalizeURL,
  Resources.mergeHeaders,
  Resources.handleHeaders,
  Resources.handleCookies,
  Resources.handleRedirect
];


module.exports = Resources;

