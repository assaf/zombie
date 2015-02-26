const HTTP = require("http");


class PortMap {

  constructor() {
  }

  map(hostname, port) {
    this._enable();
    this._ports[hostname] = port;
  }

  unmap(hostname) {
    this._enable();
    delete this._ports.hostname;
  }

  get names() {
    return Object.keys(this._ports);
  }

  _enable() {
    if (!this._ports) {
      this._ports = {};
      this._http  = HTTP.request;
      HTTP.request = this._request.bind(this);
    }
  }

  _request(options, callback) {
    const hostname = options.hostname || (options.host && options.host.split(":")[0]) || "localhost";
    const port     = options.port     || (options.host && options.host.split(":")[1]) || 80;
    if (port === 80) {
      const mapped = this._find(hostname);
      if (mapped) {
        options = Object.assign({}, options, {
          hostname: hostname,
          port:     mapped
        });
      }
    }
    return this._http(options, callback);
  }

  _find(domain) {
    // Turn domain into a list of matches, from most to least specific, e.g.
    // 'foo.example.com' turns into:
    //
    // [ 'foo.example.test',
    //   '*.foo.example.test',
    //   '*.example.test',
    //   '*.test' ]
    const parts   = domain.split('.');
    const domains = [domain];
    while (parts.length) {
      domains.push("*." + parts.join('.'));
      parts.shift();
    }

    return domains
      .map(pattern => this._ports[pattern])
      .filter(port => port)[0];
  }

}


module.exports = new PortMap();

