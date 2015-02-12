// DNS mask allows you to test against local server using a real URL, for
// example, write a test to visit http://example.com that will load a page from
// localhost.

const DNS = require("dns");
const Net = require("net");


// DNSMask hijacks Node's DNS.resolve and DNS.lookup and returns results based on
// your domain/type -> IP mapping.
module.exports = class DNSMask {

  constructor() {
    this._domains   = {};
    this._lookup    = DNS.lookup;
    DNS.lookup      = this.lookup.bind(this);
    this._resolve   = DNS.resolve;
    DNS.resolve     = this.resolve.bind(this);
    this._resolveMx = DNS.resolve;
    DNS.resolveMx   = this.resolveMx.bind(this);
  }


  // Requests for the given domain will return 127.0.0.1 (or ::1 for IPv6).
  //
  // Use asterisks to map all subdomains, e.g. *.example.com.
  localhost(domain) {
    this.map(domain, "A", "127.0.0.1");
    this.map(domain, "AAAA", "::1");
  }

  // Requests for the given domain and type will return the specified address.
  //
  // For example:
  //   map("example.com", "CNAME", "localhost")
  //   map("example.com", "A", "127.0.0.1")
  //   map("example.com", "AAAA", "::1")
  //
  // The record type (A, CNAME, etc) must be uppercase.  You can also call with
  // two arguments, to set A record (IPv4) or AAAA (IPv6).  This is equivalent:
  //   map("example.com", "localhost") // CNAME
  //   map("example.com", "127.0.0.1") // A
  //   map("example.com", "::1")       // AAAA
  //
  // Use asterisks to map all subdomains, e.g. *.example.com.
  map(domain, type, address) {
    if (arguments.length === 2) {
      address = type;
      switch (Net.isIP(address)) {
        case 4: {
          type = "A";
          break;
        }
        case 6: {
          type = "AAAA";
          break;
        }
        default: {
          type = "CNAME";
        }
      }
    }

    if (address) {
      if (!this._domains[domain])
        this._domains[domain] = {};
      this._domains[domain][type] = address;
    } else
      this.unmap(domain, type);
  }

  // Remove all mapping for the given domain/type.  With one argument, removes
  // all mapping for the given domain, of any type.
  unmap(domain, type) {
    if (type) {
      if (this._domains[domain])
        delete this._domains[domain][type];
    } else
      delete this._domains[domain];
  }


  // Alternative implementation for Node's DNS.lookup.
  lookup(domain, family, callback) {
    // With two arguments, second argument is the callback, family is 4 or 6
    if (arguments.length === 2)
      [family, callback] = [null, family];

    // If domain is missing, lookup returns null IP
    if (!domain) {
      setImmediate(function() {
        callback(null, null, 4);
      });
      return;
    }

    // If lookup called with IP address, resolve that address.
    if (Net.isIP(domain)) {
      setImmediate(function() {
        callback(null, domain, Net.isIP(domain));
      });
      return;
    }

    // First try to resolve CNAME into another domain name, then resolve that to
    // A/AAAA record
    const cname = this._find(domain, "CNAME");
    if (cname)
      domain = cname;
    if (family === 4 || !family) {
      const ipv4 = this._find(domain, "A");
      if (ipv4) {
        setImmediate(function() {
          callback(null, ipv4, 4);
        });
        return;
      }
    }
    if (family === 6 || !family) {
      const ipv6 = this._find(domain, "AAAA");
      if (ipv6) {
        setImmediate(function() {
          callback(null, ipv6, 6);
        });
        return;
      }
    }
    this._lookup(domain, family, callback);
  }

  // Alternative implementation for Node's DNS.resolve.
  resolve(domain, type, callback) {
    // With two arguments, second argument is the callback, type is 'A'
    if (arguments.length === 2)
      [type, callback] = ["A", type];
    const ip = this._find(domain, type);
    if (ip) {
      setImmediate(function() {
        callback(null, [ip]);
      });
    } else
      this._resolve(domain, type, callback);
  }

  // Alternative implementation for Node's DNS.resolveMx.
  resolveMx(domain, callback) {
    const exchange = this._find(domain, "MX");
    if (exchange) {
      setImmediate(function() {
        callback(null, [exchange]);
      });
    } else
      this._resolveMx(domain, callback);
  }


  // Returns IP address for the given domain/type.
  _find(domain, type) {
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

    return domains.map(pattern => this._domains[pattern] )
                  .map(domain  => domain && domain[type] )
                  .filter(ip   => ip)[0];
  }

};

