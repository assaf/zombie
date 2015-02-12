// Retrieve resources (HTML pages, scripts, XHR, etc).
//
// If count is unspecified, defaults to at least one.
//
// Each browser has a resources objects that allows you to:
// - Inspect the history of retrieved resources, useful for troubleshooting
//   issues related to resource loading
// - Request resources directly, but have Zombie handle cookies,
//   authentication, etc
// - Implement new mechanism for retrieving resources, for example, add new
//   protocols or support new headers


const iconv       = require('iconv-lite');
const File        = require('fs');
const DOM         = require('./dom');
const Path        = require('path');
const QS          = require('querystring');
const Request     = require('request');
const URL         = require('url');
const HTTP        = require('http');
const Zlib        = require('zlib');
const assert      = require('assert');
const { Promise } = require('bluebird');


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
  // callback  - Called with error, or null and response
  //
  // Without callback, returns a promise.
  //
  // Options:
  //   headers   - Name/value pairs of headers to send in request
  //   params    - Parameters to pass in query string or document body
  //   body      - Request document body
  //   timeout   - Request timeout in milliseconds (0 or null for no timeout)
  //
  // Response contains:
  //   url         - Actual resource URL (changed by redirects)
  //   statusCode  - Status code
  //   statusText  - HTTP status text ("OK", "Not Found" etc)
  //   headers     - Response headers
  //   body        - Response body
  //   redirects   - Number of redirects followed
  request(method, url, options = {}, callback = null) {
    if (!callback && typeof(options) === 'function')
      [options, callback] = [{}, options];

    const request = {
      method:     method.toUpperCase(),
      url:        url,
      headers:    options.headers || {},
      params:     options.params,
      body:       options.body,
      time:       Date.now(),
      timeout:    options.timeout || 0,
      strictSSL:  this.browser.strictSSL,
      localAddress: this.browser.localAddress || 0
    };

    const resource = {
      request:    request,
      target:     options.target
    };
    this.push(resource);
    this.browser.emit('request', request);

    const promise = new Promise((resolve, reject)=> {
      this.runPipeline(request, (error, response)=> {
        if (error) {
          resource.error = error;
          reject(error);
        } else {
          response.url        = response.url || request.url;
          response.statusCode = response.statusCode || 200;
          response.statusText = HTTP.STATUS_CODES[response.statusCode] || 'Unknown';
          response.headers    = response.headers || {};
          response.redirects  = response.redirects || 0;
          response.time       = Date.now();
          resource.response = response;

          this.browser.emit('response', request, response);
          resolve(resource.response);
        }
      });
    });

    if (callback) {
      promise.done((response)=> callback(null, response), callback);
    } else
      return promise;
  }


  // GET request.
  //
  // url       - Request URL
  // options   - See request() method
  // callback  - Called with error, or null and response
  get(url, options, callback) {
    return this.request('get', url, options, callback);
  }

  // POST request.
  //
  // url       - Request URL
  // options   - See request() method
  // callback  - Called with error, or null and response
  post(url, options, callback) {
    return this.request('post', url, options, callback);
  }


  // Human readable resource listing.  With no arguments, write it to stdout.
  dump(output = process.stdout) {
    for (let resource of this) {
      const { request, response, error, target } = resource;
      // Write summary request/response header
      if (response)
        output.write(`${request.method} ${response.url} - ${response.statusCode} ${response.statusText} - ${response.time - request.time}ms\n`);
      else
        output.write(`${resource.request.method} ${resource.request.url}\n`);

      // Tell us which element/document is loading this.
      if (target instanceof DOM.Document) {
        output.write('  Loaded as HTML document\n');
      } else if (target) {
        if (target.id)
          output.write(`  Loading by element #${target.id}\n`);
        else
          output.write(`  Loading as ${target.tagName} element\n`);
      }

      // If response, write out response headers and sample of document entity
      // If error, write out the error message
      // Otherwise, indicate this is a pending request
      if (response) {
        if (response.redirects)
          output.write(`  Followed ${response.redirects} redirects\n`);
        for (let name in response.headers) {
          let value = response.headers[name];
          output.write(`  ${name}: ${value}\n`);
        }
        output.write('\n');
        const sample = response.body
          .slice(0, 250)
          .toString('utf8')
          .split('\n')
          .map(line => `  ${line}`).join('\n');
        output.write(sample);
      } else if (error) {
        output.write(`  Error: ${error.message}\n`);
      } else
        output.write(`  Pending since ${new Date(request.time)}\n`);
      // Keep them separated
      output.write('\n\n');
    }
  }


  // Add a request/response handler.  This handler will only be used by this
  // browser.
  addHandler(handler) {
    assert(handler.call, 'Handler must be a function');
    assert(handler.length === 2 || handler.length === 3, 'Handler function takes 2 (request handler) or 3 (reponse handler) arguments');
    this.pipeline.push(handler);
  }

  // Processes the request using the pipeline.
  runPipeline(request, callback) {
    const { browser } = this;
    const requestHandlers = this.pipeline
      .filter(fn => fn.length === 2)
      .concat(Resources.makeHTTPRequest);
    const responseHandlers = this.pipeline
      .filter(fn => fn.length === 3);

    let response = null;
    // Called to execute the next request handler.
    function nextRequestHandler(error, responseFromHandler) {
      if (error) {
        callback(error);
      } else if (responseFromHandler) {
        // Received response, switch to processing request
        response = responseFromHandler;
        // If we get redirected and the final handler doesn't provide a URL (e.g.
        // mock response), then without this we end up with the original URL.
        response.url = response.url || request.url;
        nextResponseHandler();
      } else {
        // Use the next request handler.
        const handler = requestHandlers.shift();
        try {
          handler.call(browser, request, nextRequestHandler);
        } catch (error) {
          callback(error);
        }
      }
    }

    // Called to execute the next response handler.
    function nextResponseHandler(error, responseFromHandler) {
      if (error) {
        callback(error);
      } else {
        if (responseFromHandler)
          response = responseFromHandler;
        const handler = responseHandlers.shift();
        if (handler) {
          // Use the next response handler
          try {
            handler.call(browser, request, response, nextResponseHandler);
          } catch (error) {
            callback(error);
          }
        } else {
          // No more handlers, callback with response.
          callback(null, response);
        }
      }
    }

    // Start with first request handler
    nextRequestHandler();
  }

}



// -- Handlers

// Add a request/response handler.  This handler will be used in all browsers.
Resources.addHandler = function(handler) {
  assert(handler.call, 'Handler must be a function');
  assert(handler.length === 2 || handler.length === 3, 'Handler function takes 2 (request handler) or 3 (response handler) arguments');
  this.pipeline.push(handler);
};


// This handler normalizes the request URL.
//
// It turns relative URLs into absolute URLs based on the current document URL
// or base element, or if no document open, based on browser.site property.
//
// Also handles file: URLs and creates query string from request.params for
// GET/HEAD/DELETE requests.
Resources.normalizeURL = function(request, next) {
  if (/^file:/.test(request.url)) {
    // File URLs are special, need to handle missing slashes and not attempt
    // to parse (downcases path)
    request.url = request.url.replace(/^file:\/{1,3}/, 'file:///');
  } else {
    // Resolve URL relative to document URL/base, or for new browser, using
    // Browser.site
    if (this.document)
      request.url = DOM.resourceLoader.resolve(this.document, request.url);
    else
      request.url = URL.resolve(this.site || 'http://localhost', request.url);
  }

  if (request.params) {
    const { method } = request;
    if (method === 'GET' || method === 'HEAD' || method === 'DELETE') {
      // These methods use query string parameters instead
      const uri = URL.parse(request.url, true);
      Object.assign(uri.query, request.params);
      request.url = URL.format(uri);
    }
  }

  next();
};


// This handler mergers request headers.
//
// It combines headers provided in the request with custom headers defined by
// the browser (user agent, authentication, etc).
//
// It also normalizes all headers by down-casing the header names.
Resources.mergeHeaders = function(request, next) {
  // Header names are down-cased and over-ride default
  const headers = {
    'user-agent':       this.userAgent
  };

  // Merge custom headers from browser first, followed by request.
  for (let name in this.headers) {
    headers[name.toLowerCase()] = this.headers[name];
  }
  if (request.headers) {
    for (let name in request.headers)
      headers[name.toLowerCase()] = request.headers[name];
  }

  const { host } = URL.parse(request.url);

  // Depends on URL, don't allow over-ride.
  headers.host = host;

  // Apply authentication credentials
  const credentials = this.authenticate(host, false);
  if (credentials)
    credentials.apply(headers);

  request.headers = headers;
  next();
};


// Depending on the content type, this handler will create a request body from
// request.params, set request.multipart for uploads.
Resources.createBody = function(request, next) {
  const { method } = request;
  if (method !== 'POST' && method !== 'PUT') {
    next();
    return;
  }

  const { headers } = request;
  // These methods support document body.  Create body or multipart.
  headers['content-type'] = headers['content-type'] || 'application/x-www-form-urlencoded';
  const mimeType = headers['content-type'].split(';')[0];
  if (request.body) {
    next();
    return;
  }

  const params = request.params || {};
  switch (mimeType) {
    case 'application/x-www-form-urlencoded': {
      request.body = QS.stringify(params);
      headers['content-length'] = request.body.length;
      next();
      break;
    }

    case 'multipart/form-data': {
      if (Object.keys(params).length === 0) {
        // Empty parameters, can't use multipart
        headers['content-type'] = 'text/plain';
        request.body = '';
      } else {

        const boundary = `${new Date().getTime()}.${Math.random()}`;
        headers['content-type'] += `; boundary=${boundary}`;
        request.multipart = Object.keys(params)
          .reduce((parts, name)=> {
            const values = params[name]
              .map(value => formData(name, value) );
            return parts.concat(values);
          }, []);
      }
      next();
      break;
    }

    case 'text/plain': {
      // XHR requests use this by default
      next();
      break;
    }

    default: {
      next(new Error(`Unsupported content type ${mimeType}`));
      break;
    }
  }
};

function formData(name, value) {
  if (value.read) {
    const buffer = value.read();
    return {
      'Content-Disposition':  `form-data; name=\"${name}\"; filename=\"${value}\"`,
      'Content-Type':         value.mime || 'application/octet-stream',
      'Content-Length':       buffer.length,
      body:                   buffer
    };
  } else {
    return {
      'Content-Disposition':  `form-data; name=\"${name}\"`,
      'Content-Type':         'text/plain; charset=utf8',
      'Content-Length':       value.length,
      body:                   value
    };
  }
}


Resources.handleHTTPResponse = function(request, response, next) {
  response.headers = response.headers || {};

  const { protocol, hostname, pathname } = URL.parse(request.url);
  if (protocol !== 'http:' && protocol !== 'https:') {
    next();
    return;
  }

  // Set cookies from response
  const setCookie = response.headers['set-cookie'];
  if (setCookie)
    this.cookies.update(setCookie, hostname, pathname);

  // Number of redirects so far.
  let redirects   = request.redirects || 0;
  let redirectUrl = null;

  // Determine whether to automatically redirect and which method to use
  // based on the status code
  const { statusCode } = response;
  if (statusCode === 301 || statusCode === 307) {
    // Do not follow POST redirects automatically, only GET/HEAD
    if (request.method === 'GET' || request.method === 'HEAD')
      redirectUrl = URL.resolve(request.url, response.headers.location);
  } else if (statusCode === 302 || statusCode === 303) {
    // Follow redirect using GET (e.g. after form submission)
    redirectUrl = URL.resolve(request.url, response.headers.location);
  }

  if (redirectUrl) {

    response.url = redirectUrl;
    // Handle redirection, make sure we're not caught in an infinite loop
    ++redirects;
    if (redirects > this.maxRedirects) {
      next(new Error(`More than ${this.maxRedirects} redirects, giving up`));
      return;
    }

    const redirectHeaders = Object.assign({}, request.headers);
    // This request is referer for next
    redirectHeaders.referer = request.url;
    // These headers exist in POST request, do not pass to redirect (GET)
    delete redirectHeaders['content-type'];
    delete redirectHeaders['content-length'];
    delete redirectHeaders['content-transfer-encoding'];
    // Redirect must follow the entire chain of handlers.
    const redirectRequest = {
      method:     'GET',
      url:        response.url,
      headers:    redirectHeaders,
      redirects:  redirects,
      strictSSL:  request.strictSSL,
      time:       request.time,
      timeout:    request.timeout
    };
    this.emit('redirect', request, response, redirectRequest);
    this.resources.runPipeline(redirectRequest, next);

  } else {
    response.redirects = redirects;
    next();
  }
};


// Handle deflate and gzip transfer encoding.
Resources.decompressBody = function(request, response, next) {
  const transferEncoding  = response.headers['transfer-encoding'];
  const contentEncoding   = response.headers['content-encoding'];
  if (contentEncoding === 'deflate' || transferEncoding === 'deflate') {
    Zlib.inflate(response.body, (error, buffer)=> {
      response.body = buffer;
      next(error);
    });
  }
  else if (contentEncoding === 'gzip' || transferEncoding === 'gzip') {
    Zlib.gunzip(response.body, (error, buffer)=> {
      response.body = buffer;
      next(error);
    });
  } else
    next();
};


// Find the charset= value of the meta tag
const MATCH_CHARSET = /<meta(?!\s*(?:name|value)\s*=)[^>]*?charset\s*=[\s"']*([^\s"'\/>]*)/i;

// This handler decodes the response body based on the response content type.
Resources.decodeBody = function(request, response, next) {
  if (!Buffer.isBuffer(response.body)) {
    next();
    return;
  }

  // If Content-Type header specifies charset, use that
  const contentType = response.headers['content-type'] || 'application/unknown';
  const [mimeType, ...typeOptions]  = contentType.split(/;\s*/);
  const [type, subtype]             = contentType.split(/\//,2);

  // Images, binary, etc keep response body a buffer
  if (type && type !== 'text') {
    next();
    return;
  }

  let charset = null;

  // Pick charset from content type
  if (mimeType) {
    for (let typeOption of typeOptions) {
      if (/^charset=/i.test(typeOption)) {
        charset = typeOption.split('=')[1];
        break;
      }
    }
  }

  // Otherwise, HTML documents only, pick charset from meta tag
  // Otherwise, HTML documents only, default charset in US is windows-1252
  const isHTML = /html/.test(subtype) || /\bhtml\b/.test(request.headers.accept);
  if (!charset && isHTML) {
    const match = response.body.toString().match(MATCH_CHARSET);
    charset = match ? match[1] : 'windows-1252';
  }

  if (charset)
    response.body = iconv.decode(response.body, charset);
  next();
};


// All browsers start out with this list of handler.
Resources.pipeline = [
  Resources.normalizeURL,
  Resources.mergeHeaders,
  Resources.createBody,
  Resources.handleHTTPResponse,
  Resources.decompressBody,
  Resources.decodeBody
];


// -- Make HTTP request


// Used to perform HTTP request (also supports file: resources).  This is always
// the last request handler.
Resources.makeHTTPRequest = function(request, callback) {
  const { protocol, hostname, pathname } = URL.parse(request.url);
  if (protocol === 'file:') {

    // If the request is for a file:// descriptor, just open directly from the
    // file system rather than getting node's http (which handles file://
    // poorly) involved.
    if (request.method !== 'GET') {
      callback(null, { statusCode: 405 });
      return;
    }

    const filename = Path.normalize(decodeURI(pathname));
    File.exists(filename, function(exists) {
      if (exists) {
        File.readFile(filename, function(error, buffer) {
          // Fallback with error -> callback
          if (error) {
            request.error = error;
            callback(error);
          } else
            callback(null, { body: buffer });
        });
      } else
        callback(null, { statusCode: 404 });
    });

  } else {

    // We're going to use cookies later when recieving response.
    const { cookies } = this;
    request.headers.cookie = cookies.serialize(hostname, pathname);

    const httpRequest = {
      method:         request.method,
      url:            request.url,
      headers:        request.headers,
      body:           request.body,
      multipart:      request.multipart,
      proxy:          this.proxy,
      jar:            false,
      followRedirect: false,
      encoding:       null,
      strictSSL:      request.strictSSL,
      localAddress:   request.localAddress || 0,
      timeout:        request.timeout || 0
    };

    Request(httpRequest, function(error, response) {
      if (error) {
        callback(error);
      } else {
        callback(null, {
          url:          request.url,
          statusCode:   response.statusCode,
          headers:      response.headers,
          body:         response.body,
          redirects:    request.redirects || 0
        });
      }
    });


  }

};


module.exports = Resources;

