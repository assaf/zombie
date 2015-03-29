const _   = require('lodash');


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


module.exports = { Headers };
