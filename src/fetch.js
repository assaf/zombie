const _       = require('lodash');
const HTTP    = require('http');
const Promise = require('bluebird');
const Stream  = require('stream');
const URL     = require('url');
const Zlib    = require('zlib');


// Decompress stream based on content and transfer encoding headers.
function decompressStream(stream, headers) {
  const transferEncoding  = headers.get('Transfer-Encoding');
  const contentEncoding   = headers.get('Content-Encoding');
  if (contentEncoding === 'deflate' || transferEncoding === 'deflate')
    return stream.pipe( Zlib.createInflate() );
  if (contentEncoding === 'gzip' || transferEncoding === 'gzip')
    return stream.pipe( Zlib.createGunzip() );
  return stream;
}


// Convert bodyInit argument into a stream / contentType pair we can use to
// initialize a Response.
function createStreamFromBodyInit(bodyInit) {
  if (!bodyInit)
    return {};

  if (bodyInit instanceof Stream.Readable)
    return { stream: bodyInit };

  if (typeof bodyInit === 'string' || bodyInit instanceof String) {
    const streamFromString = new Stream.Readable();
    streamFromString._read = function() {
      this.push(bodyInit);
      this.push(null);
    };
    return { stream: streamFromString, contentType: 'text/plain;charset=UTF-8' };
  }

  throw new TypeError('This body type not yet supported');
}


// https://fetch.spec.whatwg.org/#headers-class
class Headers {

  constructor(init) {
    this._headers = [];
    if (init instanceof Headers)
      for (let [name, value] of init)
        this.append(name, value);
    else if (init instanceof Array)
      for (let [name, value] of init)
        this.append(name, value);
    else if (init instanceof Object)
      _.each(init, (value, name)=> {
        this.append(name, value);
      });
  }

  append(name, value) {
    const caseInsensitive = name.toLowerCase();
    const castValue       = String(value).replace(/\r\n/g, '');
    this._headers.push([caseInsensitive, castValue]);
  }

  delete(name) {
    const caseInsensitive = name.toLowerCase();
    this._headers = this._headers.filter(([name]) => name !== caseInsensitive);
  }

  get(name) {
    const caseInsensitive = name.toLowerCase();
    const header = _.find(this._headers, ([name]) => name === caseInsensitive);
    return header && header[1];
  }

  getAll(name) {
    const caseInsensitive = name.toLowerCase();
    return this._headers
      .filter(([name]) => name === caseInsensitive)
      .map(([name, value]) => value);
  }

  has(name) {
    const caseInsensitive = name.toLowerCase();
    const header = _.find(this._headers, ([name, value]) => name === caseInsensitive);
    return !!header;
  }

  set(name, value) {
    const caseInsensitive = name.toLowerCase();
    const castValue       = String(value).replace(/\r\n/g, '');
    let   replaced        = false;
    this._headers = this._headers.reduce((headers, [name, value])=> {
      if (name === caseInsensitive) {
        if (!replaced) {
          headers.push([name, castValue]);
          replaced = true;
        }
      } else
        headers.push([name, value]);
      return headers;
    }, []);

    if (!replaced)
      this.append(name, castValue);
  }

  [Symbol.iterator]() {
    return this._headers[Symbol.iterator]();
  }

  valueOf() {
    return [for ([name, value] of this._headers) `${name}: ${value}`];
  }

  toString() {
    return this.valueOf().join('\n');
  }

  toObject() {
    const object = Object.create(null);
    for (let [name, value] of this._headers)
      object[name] = value;
    return object;
  }

}


class Response {

  constructor(bodyInit, responseInit) {
    if (responseInit) {
      if (responseInit.status < 200 || responseInit.status > 599)
        throw new RangeError(`Status code ${responseInit.status} not in range`);
      const statusText = responseInit.statusText || HTTP.STATUS_CODES[responseInit.status] || 'Unknown';
      if (!/^[^\n\r]+$/.test(statusText))
        throw new TypeError(`Status text ${responseInit.statusText} not valid format`);

      this._url       = URL.format(responseInit.url || '');
      this.type       = 'default';
      this.status     = responseInit.status;
      this.statusText = statusText;
      this.headers    = new Headers(responseInit.headers);
      this.redirects  = responseInit.redirects || 0;
    } else {
      this.type       = 'error';
      this.status     = 0;
      this.statusText = '';
      this.headers    = new Headers();
    }

    if (bodyInit) {
      const { stream, contentType } = createStreamFromBodyInit(bodyInit);
      this._stream = stream;
      if (contentType != null && !this.headers.has('Content-Type'))
        this.headers.set('Content-Type', contentType);
    }
  }

  // -- From response interface --

  get url() {
    return (this._url || '').split('#')[0];
  }

  get ok() {
    return (this.status >= 200 && this.status <= 299);
  }

  clone() {
    throw new Error('Not implemented yet');
  }

  static error() {
    return new Response();
  }

  static redirect(url, status = 302) {
    const parsedURL = URL.parse(url);
    if ([301, 302, 303, 307, 308].indexOf(status) < 0)
      throw new RangeError(`Status code ${status} not valid redirect code`);
    const statusText = HTTP.STATUS_CODES[status];
    const response = new Response(null, { status, statusText });
    response.headers.set('Location', URL.format(parsedURL));
    return response;
  }


  // -- From Body interface --

  get bodyUsed() {
    return !this._stream;
  }

  async arrayBuffer() {
    this.body         = await this._consume();
    const arrayBuffer = new Uint8Array(this.body.length);
    for (let i = 0; i < this.body.length; ++i)
      arrayBuffer[i] = this.body[i];
    return arrayBuffer;
  }

  async blob() {
    throw new Error('Not implemented yet');
  }

  async formData() {
    const buffer      = await this._consume();
    const contentType = this.headers.get('Content-Type') || '';
    const mimeType    = contentType.split(';')[0];
    switch (mimeType) {
      case 'multipart/form-data': {
        throw new Error('Not implemented yet');
      }
      case 'application/x-www-form-urlencoded': {
        throw new Error('Not implemented yet');
      }
      default: {
        throw new TypeError(`formData does not support MIME type ${mimeType}`);
      }
    }
  }

  async json() {
    const buffer  = await this._consume();
    this.body     = buffer.toString('utf-8');
    return JSON.parse(this.body);
  }

  async text() {
    const buffer      = await this._consume();
    this.body         = buffer.toString();
    return this.body;
  }


  // -- Implementation details --

  async _consume() {
    if (!this._stream)
      throw new TypeError('Body already consumed');
    const stream  = this._stream;
    this._stream  = null;

    if (!stream.readable)
      return new Buffer('');

    const decompressed = decompressStream(stream, this.headers);

    return await new Promise((resolve)=> {
      const buffers = [];
      decompressed
        .on('data', (buffer)=> {
          buffers.push(buffer);
        })
        .on('end', ()=> {
          resolve(Buffer.concat(buffers));
        })
        .on('error', ()=> {
          resolve(Buffer.concat(buffers));
        })
        .resume();
    });
  }
}


module.exports = {
  Headers,
  Response
};
