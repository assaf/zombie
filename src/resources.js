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


const assert      = require('assert');
const Bluebird    = require('bluebird');
const DOM         = require('./dom');
const File        = require('fs');
const HTTP        = require('http');
const iconv       = require('iconv-lite');
const Path        = require('path');
const QS          = require('querystring');
const request     = require('request');
const URL         = require('url');
const Zlib        = require('zlib');


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
    if (!callback && typeof options === 'function')
      [options, callback] = [{}, options];

    const req = {
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
      request:    req,
      target:     options.target
    };
    this.push(resource);
    this.browser.emit('request', req);

    const promise = new Bluebird((resolve, reject)=> {
      this.runPipeline(req, (error, res)=> {
        if (error) {
          resource.error = error;
          reject(error);
        } else {
          res.url           = res.url || req.url;
          res.statusCode    = res.statusCode || 200;
          res.statusText    = HTTP.STATUS_CODES[res.statusCode] || 'Unknown';
          res.headers       = res.headers || {};
          res.redirects     = res.redirects || 0;
          res.time          = Date.now();
          resource.response = res;

          this.browser.emit('response', req, res);
          resolve(resource.response);
        }
      });
    });

    if (callback)
      promise.done((res)=> callback(null, res), callback);
    else
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


  // Human readable resource listing.
  //
  // output - Write to this stream (optional)
  dump(output = process.stdout) {
    if (this.length === 0) {
      output.write('No resources\n');
      return;
    }

    for (let resource of this) {
      const { request, response, error, target } = resource;
      // Write summary request/response header
      if (response)
        output.write(`${request.method} ${response.url} - ${response.statusCode} ${response.statusText} - ${response.time - request.time}ms\n`);
      else
        output.write(`${resource.request.method} ${resource.request.url}\n`);

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
        for (let name in response.headers) {
          let value = response.headers[name];
          output.write(`  ${name}: ${value}\n`);
        }
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


  // Add a request/response handler.  This handler will only be used by this
  // browser.
  addHandler(handler) {
    assert(handler.call, 'Handler must be a function');
    assert(handler.length === 2 || handler.length === 3, 'Handler function takes 2 (request handler) or 3 (reponse handler) arguments');
    this.pipeline.push(handler);
  }

  // Processes the request using the pipeline.
  runPipeline(req, callback) {
    const { browser } = this;
    const requestHandlers = this.pipeline
      .filter(fn => fn.length === 2)
      .concat(Resources.makeHTTPRequest);
    const responseHandlers = this.pipeline
      .filter(fn => fn.length === 3);

    let res = null;
    // Called to execute the next request handler.
    function nextRequestHandler(error, responseFromHandler) {
      if (error) {
        callback(error);
        return;
      }

      if (responseFromHandler) {
        // Received response, switch to processing request
        res = responseFromHandler;
        // If we get redirected and the final handler doesn't provide a URL (e.g.
        // mock response), then without this we end up with the original URL.
        res.url = res.url || req.url;
        nextResponseHandler();
      } else {
        // Use the next request handler.
        const handler = requestHandlers.shift();
        try {
          handler.call(browser, req, nextRequestHandler);
        } catch (error) {
          callback(error);
        }
      }
    }

    // Called to execute the next response handler.
    function nextResponseHandler(error, responseFromHandler) {
      if (error) {
        callback(error);
        return;
      }

      if (responseFromHandler)
        res = responseFromHandler;

      const handler = responseHandlers.shift();
      if (handler)
        // Use the next response handler
        try {
          handler.call(browser, req, res, nextResponseHandler);
        } catch (error) {
          callback(error);
        }
      else
        // No more handlers, callback with response.
        callback(null, res);
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
Resources.normalizeURL = function(req, next) {
  if (/^file:/.test(req.url))
    // File URLs are special, need to handle missing slashes and not attempt
    // to parse (downcases path)
    req.url = req.url.replace(/^file:\/{1,3}/, 'file:///');
  else if (this.document)
  // Resolve URL relative to document URL/base, or for new browser, using
  // Browser.site
    req.url = DOM.resourceLoader.resolve(this.document, req.url);
  else
    req.url = URL.resolve(this.site || 'http://localhost', req.url);

  if (req.params) {
    const { method } = req;
    if (method === 'GET' || method === 'HEAD' || method === 'DELETE') {
      // These methods use query string parameters instead
      const uri = URL.parse(req.url, true);
      Object.assign(uri.query, req.params);
      req.url = URL.format(uri);
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
Resources.mergeHeaders = function(req, next) {
  // Header names are down-cased and over-ride default
  const headers = {
    'user-agent':       this.userAgent
  };

  // Merge custom headers from browser first, followed by request.
  for (let name in this.headers) {
    headers[name.toLowerCase()] = this.headers[name];
  }
  if (req.headers)
    for (let name in req.headers)
      headers[name.toLowerCase()] = req.headers[name];

  const { host } = URL.parse(req.url);

  // Depends on URL, don't allow over-ride.
  headers.host = host;

  // HTTP Basic authentication
  const authenticate = { host, username: null, password: null };
  this.emit('authenticate', authenticate);
  const { username, password } = authenticate;
  if (username && password) {
    this.log(`Authenticating as ${username}:${password}`);
    const base64 = new Buffer(`${username}:${password}`).toString('base64');
    headers.authorization = `Basic ${base64}`;
  }

  req.headers = headers;
  next();
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
  } else
    return {
      'Content-Disposition':  `form-data; name=\"${name}\"`,
      'Content-Type':         'text/plain; charset=utf8',
      'Content-Length':       value.length,
      body:                   value
    };
}


// Depending on the content type, this handler will create a request body from
// request.params, set request.multipart for uploads.
Resources.createBody = function(req, next) {
  const { method } = req;
  if (method !== 'POST' && method !== 'PUT') {
    next();
    return;
  }

  const { headers } = req;
  // These methods support document body.  Create body or multipart.
  headers['content-type'] = headers['content-type'] || 'application/x-www-form-urlencoded';
  const mimeType = headers['content-type'].split(';')[0];
  if (req.body) {
    next();
    return;
  }

  const params = req.params || {};
  switch (mimeType) {
    case 'application/x-www-form-urlencoded': {
      req.body = QS.stringify(params);
      headers['content-length'] = req.body.length;
      next();
      break;
    }

    case 'multipart/form-data': {
      if (Object.keys(params).length === 0) {
        // Empty parameters, can't use multipart
        headers['content-type'] = 'text/plain';
        req.body = '';
      } else {

        const boundary = `${new Date().getTime()}.${Math.random()}`;
        headers['content-type'] += `; boundary=${boundary}`;
        req.multipart = Object.keys(params)
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



Resources.handleHTTPResponse = function(req, res, next) {
  res.headers = res.headers || {};

  const { protocol, hostname, pathname } = URL.parse(req.url);
  if (protocol !== 'http:' && protocol !== 'https:') {
    next();
    return;
  }

  // Set cookies from response
  const setCookie = res.headers['set-cookie'];
  if (setCookie)
    this.cookies.update(setCookie, hostname, pathname);

  // Number of redirects so far.
  let redirects   = req.redirects || 0;
  let redirectUrl = null;

  // Determine whether to automatically redirect and which method to use
  // based on the status code
  const { statusCode } = res;
  if ((statusCode === 301 || statusCode === 307) &&
      (req.method === 'GET' || req.method === 'HEAD'))
    // Do not follow POST redirects automatically, only GET/HEAD
    redirectUrl = URL.resolve(req.url, res.headers.location || '');
  else if (statusCode === 302 || statusCode === 303)
    // Follow redirect using GET (e.g. after form submission)
    redirectUrl = URL.resolve(req.url, res.headers.location || '');

  if (redirectUrl) {

    res.url = redirectUrl;
    // Handle redirection, make sure we're not caught in an infinite loop
    ++redirects;
    if (redirects > this.maxRedirects) {
      next(new Error(`More than ${this.maxRedirects} redirects, giving up`));
      return;
    }

    const redirectHeaders = Object.assign({}, req.headers);
    // This request is referer for next
    redirectHeaders.referer = req.url;
    // These headers exist in POST request, do not pass to redirect (GET)
    delete redirectHeaders['content-type'];
    delete redirectHeaders['content-length'];
    delete redirectHeaders['content-transfer-encoding'];
    // Redirect must follow the entire chain of handlers.
    const redirectRequest = {
      method:     'GET',
      url:        res.url,
      headers:    redirectHeaders,
      redirects:  redirects,
      strictSSL:  req.strictSSL,
      time:       req.time,
      timeout:    req.timeout
    };
    this.emit('redirect', req, res, redirectRequest);
    this.resources.runPipeline(redirectRequest, next);

  } else {
    res.redirects = redirects;
    next();
  }
};


// Handle deflate and gzip transfer encoding.
Resources.decompressBody = function(req, res, next) {
  const transferEncoding  = res.headers['transfer-encoding'];
  const contentEncoding   = res.headers['content-encoding'];
  if (contentEncoding === 'deflate' || transferEncoding === 'deflate')
    Zlib.inflate(res.body, (error, buffer)=> {
      res.body = buffer;
      next(error);
    });
  else if (contentEncoding === 'gzip' || transferEncoding === 'gzip')
    Zlib.gunzip(res.body, (error, buffer)=> {
      res.body = buffer;
      next(error);
    });
  else
    next();
};


// Find the charset= value of the meta tag
const MATCH_CHARSET = /<meta(?!\s*(?:name|value)\s*=)[^>]*?charset\s*=[\s"']*([^\s"'\/>]*)/i;

// This handler decodes the response body based on the response content type.
Resources.decodeBody = function(req, res, next) {
  if (!Buffer.isBuffer(res.body)) {
    next();
    return;
  }

  // If Content-Type header specifies charset, use that
  const contentType = res.headers['content-type'] || 'application/unknown';
  const [mimeType, ...typeOptions]  = contentType.split(/;\s*/);
  const [type, subtype]             = contentType.split(/\//, 2);

  // Images, binary, etc keep response body a buffer
  if (type && type !== 'text') {
    next();
    return;
  }

  let charset = null;

  // Pick charset from content type
  if (mimeType)
    for (let typeOption of typeOptions) {
      if (/^charset=/i.test(typeOption)) {
        charset = typeOption.split('=')[1];
        break;
      }
    }

  // Otherwise, HTML documents only, pick charset from meta tag
  // Otherwise, HTML documents only, default charset in US is windows-1252
  const isHTML = /html/.test(subtype) || /\bhtml\b/.test(req.headers.accept);
  if (!charset && isHTML) {
    const match = res.body.toString().match(MATCH_CHARSET);
    charset = match ? match[1] : 'windows-1252';
  }

  if (charset)
    res.body = iconv.decode(res.body, charset);
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
Resources.makeHTTPRequest = function(req, callback) {
  const { protocol, hostname, pathname } = URL.parse(req.url);
  if (protocol === 'file:') {

    // If the request is for a file:// descriptor, just open directly from the
    // file system rather than getting node's http (which handles file://
    // poorly) involved.
    if (req.method !== 'GET') {
      callback(null, { statusCode: 405 });
      return;
    }

    const filename = Path.normalize(decodeURI(pathname));
    File.exists(filename, function(exists) {
      if (exists)
        File.readFile(filename, function(error, buffer) {
          // Fallback with error -> callback
          if (error) {
            req.error = error;
            callback(error);
          } else
            callback(null, { body: buffer });
        });
      else
        callback(null, { statusCode: 404 });
    });

  } else {

    // We're going to use cookies later when recieving response.
    const { cookies } = this;
    req.headers.cookie = cookies.serialize(hostname, pathname);

    const httpRequest = {
      method:         req.method,
      url:            req.url,
      headers:        req.headers,
      body:           req.body,
      multipart:      req.multipart,
      proxy:          this.proxy,
      jar:            false,
      followRedirect: false,
      encoding:       null,
      strictSSL:      req.strictSSL,
      localAddress:   req.localAddress || 0,
      timeout:        req.timeout || 0
    };

    request(httpRequest, function(error, res) {
      if (error)
        callback(error);
      else
        callback(null, {
          url:          req.url,
          statusCode:   res.statusCode,
          headers:      res.headers,
          body:         res.body,
          redirects:    req.redirects || 0
        });
    });


  }

};


module.exports = Resources;

