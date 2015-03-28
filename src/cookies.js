// See [RFC 2109](http://tools.ietf.org/html/rfc2109.html) and
// [document.cookie](http://dev/loper.mozilla.org/en/document.cookie)
const DOM         = require('./dom');
const { isArray } = require('util');
const Tough       = require('tough-cookie');
const { Cookie }  = Tough;


// Lists all available cookies.
module.exports = class Cookies extends Array {

  // Used to dump state to console (debugging)
  dump(output = process.stdout) {
    for (let cookie of this.sort(Tough.cookieCompare))
      output.write(`${cookie}\n`);
  }

  // Serializes all selected cookies into a single string.  Used to generate a cookies header.
  //
  // domain - Request hostname
  // path   - Request pathname
  serialize(domain, path) {
    return this
      .select({ domain: domain, path: path })
      .map(cookie => cookie.cookieString())
      .join('; ');
  }

  // Returns all cookies that match the identifier (name, domain and path).
  // This is used for retrieving cookies.
  select(identifier) {
    let cookies = this.filter(cookie => cookie.TTL() > 0); // eslint-disable-line new-cap
    if (identifier.name)
      cookies = cookies.filter(cookie => cookie.key === identifier.name);
    if (identifier.path)
      cookies = cookies.filter(cookie => Tough.pathMatch(identifier.path, cookie.path));
    if (identifier.domain)
      cookies = cookies.filter(cookie => Tough.domainMatch(identifier.domain, cookie.domain));
    return cookies
      .sort((a, b)=> b.domain.length - a.domain.length)
      .sort(Tough.cookieCompare);
  }

  // Adds a new cookie, updates existing cookie (same name, domain and path), or
  // deletes a cookie (if expires in the past).
  set(params) {
    const cookie = new Cookie({
      key:    params.name,
      value:  params.value,
      domain: params.domain || 'localhost',
      path:   params.path || '/'
    });
    if (params.expires)
      cookie.setExpires(params.expires);
    else if (params.hasOwnProperty('max-age'))
      cookie.setMaxAge(params['max-age']);
    cookie.secure   = !!params.secure;
    cookie.httpOnly = !!params.httpOnly;

    // Delete cookie before setting it, so we only store one cookie (per
    // domain/path/name)
    this
      .filter(c   => c.domain === cookie.domain)
      .filter(c   => c.path === cookie.path)
      .filter(c   => c.key === cookie.key)
      .forEach(c  => this.delete(c));
    if (cookie.TTL() > 0) // eslint-disable-line new-cap
      this.push(cookie);
  }

  // Delete the specified cookie.
  delete(cookie) {
    const index = this.indexOf(cookie);
    if (~index)
      this.splice(index, 1);
  }

  // Deletes all cookies.
  deleteAll() {
    this.length = 0;
  }

  // Update cookies with HTTP response
  //
  // httpHeader - Value of HTTP Set-Cookie header (string/array)
  // domain     - Set from hostname
  // path       - Set from pathname
  update(httpHeader, domain, path) {
    // One Set-Cookie is a string, multiple is an array
    const cookies = isArray(httpHeader) ? httpHeader : [httpHeader];
    cookies
      .map(cookie => Cookie.parse(cookie))
      .filter(cookie => cookie)
      .forEach(cookie => {
        cookie.domain = cookie.domain || domain;
        cookie.path   = cookie.path || Tough.defaultPath(path);

        // Delete cookie before setting it, so we only store one cookie (per
        // domain/path/name)
        this
          .filter(c   => c.domain === cookie.domain)
          .filter(c   => c.path === cookie.path)
          .filter(c   => c.key === cookie.key)
          .forEach(c  => this.delete(c));
        if (cookie.TTL() > 0) // eslint-disable-line new-cap
          this.push(cookie);
      });
  }

};


// Returns name=value pairs
DOM.HTMLDocument.prototype.__defineGetter__('cookie', function() {
  const { cookies } = this.window.browser;
  return cookies
    .select({ domain: this.location.hostname, path: this.location.pathname })
    .filter(cookie => !cookie.httpOnly)
    .map(cookie    => `${cookie.key}=${cookie.value}`)
    .join('; ');
});

// Accepts serialized form (same as Set-Cookie header) and updates cookie from
// new values.
DOM.HTMLDocument.prototype.__defineSetter__('cookie', function(cookie) {
  const { cookies } = this.window.browser;
  cookies.update(cookie.toString(), this.location.hostname, this.location.pathname);
});
