const assert  = require('assert');
const brains  = require('./helpers/brains');
const Browser = require('../src');


// Parse string with cookies in it (like document.cookies) and return object
// with name/value pairs for each cookie.
function parse(cookies) {
  return cookies
    .split(/;\s*/)
    .map((cookie)=> cookie.split('='))
    .reduce(function(all, [name, value]) {
      all[name] = value.replace(/^"(.*)"$/, '$1');
      return all;
    }, Object.create({}));
}

// Extracts cookies from @browser, parses and sets @cookies.
function cookiesFromHtml(browser) {
  return parse(browser.source);
}


describe('Cookies', function() {
  const browser = new Browser();

  before(function() {
    return brains.ready();
  });

  before(function() {
    brains.get('/cookies', function(req, res) {
      res.cookie('_name',       'value');
      res.cookie('_expires1',   '3s',       { expires: new Date(Date.now() + 3000) });
      res.cookie('_expires2',   '5s',       { 'Max-Age': 5000 });
      res.cookie('_expires3',   '0s',       { expires: new Date(Date.now() - 100) });
      res.cookie('_path1',      'yummy',    { path: '/cookies' });
      res.cookie('_path2',      'yummy',    { path: '/cookies/sub' });
      res.cookie('_path3',      'wrong',    { path: '/wrong' });
      res.cookie('_path4',      'yummy',    { path: '/' });
      res.cookie('_domain1',    'here',     { domain: '.example.com' });
      res.cookie('_domain2',    'not here', { domain: 'not.example.com' });
      res.cookie('_domain3',    'wrong',    { domain: 'notexample.com' });
      res.cookie('_multiple',   'specific', { path: '/cookies' });
      res.cookie('_multiple',   'general',  { path: '/' });
      res.cookie('_http_only',  'value',    { httpOnly: true });
      res.cookie('_dup',        'one',      { path: '/' });
      res.send('<html></html>');
    });

    brains.get('/cookies/invalid', function(req, res) {
      res.setHeader('Set-Cookie', 'invalid');
      res.send('<html></html>');
    });

    brains.get('/cookies/echo', function(req, res) {
      const cookies = Object.keys(req.cookies).map((key)=> {
        const value = req.cookies[key];
        return `${key}=${value}`;
      }).join('; ');
      res.send(cookies);
    });

    brains.get('/cookies/empty', function(req, res) {
      res.send('');
   });
  });


  // -- Browser API --

  describe('getCookie', function() {
    before(function() {
      browser.deleteCookies();
      browser.setCookie({ name: 'foo', domain: '.example.com',    value: 'partial domain' });
      browser.setCookie({ name: 'foo', domain: 'www.example.com', value: 'full domain' });
      browser.setCookie({ name: 'foo', domain: '.example.com',    path: '/bar', value: 'full path' });
    });

    it('should find cookie by name', function() {
      browser.visit('http://example.com/');
      assert.equal(browser.getCookie('foo'), 'partial domain');
      browser.close();
    });

    it('should find cookie with most specific domain', function() {
      assert.equal(browser.getCookie({ name: 'foo', domain: 'dox.example.com' }), 'partial domain');
      assert.equal(browser.getCookie({ name: 'foo', domain: 'example.com' }),     'partial domain');
      assert.equal(browser.getCookie({ name: 'foo', domain: 'www.example.com' }), 'full domain');
    });

    it('should find cookie with most specific path', function() {
      assert.equal(browser.getCookie({ name: 'foo', domain: 'example.com', path: '/' }),     'partial domain');
      assert.equal(browser.getCookie({ name: 'foo', domain: 'example.com', path: '/bar' }),  'full path');
    });

    it('should return cookie object if second argument is true', function() {
      assert.deepEqual(browser.getCookie({ name: 'foo', domain: 'www.example.com' }, true), {
        name:   'foo',
        value:  'full domain',
        domain: 'www.example.com',
        path:   '/'
      });
    });

    it('should return null if no match', function() {
      assert.equal(browser.getCookie({ name: 'unknown', domain: 'example.com' }), null);
    });

    it('should return null if no match and second argument is true', function() {
      assert.equal(browser.getCookie({ name: 'unknown', domain: 'example.com' }, true), null);
    });

    it('should fail if no domain specified', function() {
      assert.throws(function() {
        assert.equal(browser.getCookie('no-domain'));
      }, 'No domain specified and no open page');

    });
  });


  describe('deleteCookie', function() {

    describe('by name', function() {
      before(function() {
        browser.deleteCookies();
        browser.visit('http://example.com/');
        browser.setCookie('foo', 'delete me');
        browser.setCookie('bar', 'keep me');
      });

      it('should delete that cookie', function() {
        browser.assert.cookie('foo', 'delete me');
        assert(browser.deleteCookie('foo'));
        browser.assert.cookie('foo', null);
        browser.assert.cookie('bar', 'keep me');
      });

      after(function() {
        browser.close();
      });
    });


    describe('by name and domain', function() {
      before(function() {
        browser.deleteCookies();
        browser.setCookie({ name: 'foo', domain: 'www.example.com', value: 'delete me' });
        browser.setCookie({ name: 'foo', domain: '.example.com',    value: 'keep me' });
      });

      it('should delete that cookie', function() {
        browser.assert.cookie({ name: 'foo', domain: 'www.example.com' }, 'delete me');
        assert(browser.deleteCookie({ name: 'foo', domain: 'www.example.com' }));
        browser.assert.cookie({ name: 'foo', domain: 'www.example.com' }, 'keep me');
      });
    });


    describe('by name, domain and path', function() {
      before(function() {
        browser.deleteCookies();
        browser.setCookie({ name: 'foo', domain: 'example.com', path: '/',    value: 'keep me' });
        browser.setCookie({ name: 'foo', domain: 'example.com', path: '/bar', value: 'delete me' });
      });

      it('should delete that cookie', function() {
        browser.assert.cookie({ name: 'foo', domain: 'example.com', path: '/bar' }, 'delete me');
        assert(browser.deleteCookie({ name: 'foo', domain: 'example.com', path: '/bar' }));
        browser.assert.cookie({ name: 'foo', domain: 'example.com', path: '/bar' }, 'keep me');
      });
    });
  });


  describe('deleteCookies', function() {
    before(function() {
      browser.deleteCookies();
      browser.visit('http://example.com/');
      browser.setCookie('foo', 'delete me');
      browser.setCookie('bar', 'keep me');
    });

    it('should delete all cookies', function() {
      browser.deleteCookies();
      browser.assert.cookie('foo', null);
      browser.assert.cookie('bar', null);
      assert.equal(browser.cookies.length, 0);
    });

    after(function() {
      browser.close();
    });
  });


  // -- Sending and receiving --


  describe('receive cookies', function() {

    before(function() {
      browser.deleteCookies();
      return browser.visit('/cookies');
    });

    describe('cookies', function() {
      it('should have access to session cookie', function() {
        browser.assert.cookie('_name', 'value');
      });
      it('should have access to persistent cookie', function() {
        browser.assert.cookie('_expires1', '3s');
        browser.assert.cookie('_expires2', '5s');
      });
      it('should not have access to expired cookies', function() {
        browser.assert.cookie('_expires3', null);
      });
      it('should have access to cookies for the path /cookies', function() {
        browser.assert.cookie('_path1', 'yummy');
      });
      it('should have access to cookies for paths which are ancestors of /cookies', function() {
        browser.assert.cookie('_path4', 'yummy');
      });
      it('should not have access to other paths', function() {
        browser.assert.cookie('_path2', null);
        browser.assert.cookie('_path3', null);
      });
      it('should have access to .domain', function() {
        browser.assert.cookie('_domain1', 'here');
      });
      it('should not have access to other domains', function() {
        browser.assert.cookie('_domain2', null);
        browser.assert.cookie('_domain3', null);
      });
      it('should access most specific cookie', function() {
        browser.assert.cookie('_multiple', 'specific');
      });
    });

    describe('invalid cookie', function() {
      before(function() {
        return browser.visit('/cookies/invalid');
      });

      it('should not have the cookie', function() {
        browser.assert.cookie('invalid', null);
      });
    });

    describe('host in domain', function() {
      it('should have access to host cookies', function() {
        browser.assert.cookie('_domain1', 'here');
      });
      it('should not have access to other host cookies', function() {
        browser.assert.cookie('_domain2', null);
        browser.assert.cookie('_domain3', null);
      });
    });

    describe('document.cookie', function() {

      it('should return name/value pairs', function() {
        const cookie = browser.document.cookie;
        assert(/^(\w+=\w+; )+\w+=\w+$/.test(cookie));
      });

      describe('pairs', function() {
        let pairs;

        before(function() {
          const cookie = browser.document.cookie;
          pairs = parse(cookie);
        });

        it('should include only visible cookies', function() {
          const keys = Object.keys(pairs).sort();
          assert.deepEqual(keys, '_domain1 _dup _expires1 _expires2 _multiple _name _path1 _path4'.split(' '));
        });
        it('should match name to value', function() {
          assert.equal(pairs._name, 'value');
          assert.equal(pairs._path1, 'yummy');
        });
        it('should not include httpOnly cookies', function() {
          for (let key in pairs)
            assert(key !== '_http_only');
        });
      });
    });
  });


  describe('host', function() {

    before(function() {
      browser.deleteCookies();
      return browser.visit('/cookies');
    });

    it('should be able to set domain cookies', function() {
      browser.assert.cookie({ name: '_domain1', domain: 'example.com', path: '/cookies' }, 'here');
    });
  });


  describe('receive cookies and redirect', function() {
    before(function() {
      brains.get('/cookies/redirect', function(req, res) {
        res.cookie('_expires4', '3s');  // expires: new Date(Date.now() + 3000), 'Path': '/'
        res.redirect('/');
      });

      browser.deleteCookies();
      return browser.visit('/cookies/redirect');
    });

    it('should have access to persistent cookie', function() {
      browser.assert.cookie({ name: '_expires4', domain: 'example.com', path: '/cookies/redirect' }, '3s');
    });
  });


  describe('duplicates', function() {

    before(async function() {
      brains.get('/cookies2', function(req, res) {
        res.cookie('_dup', 'two', { path: '/' });
        res.send('');
      });
      brains.get('/cookies3', function(req, res) {
        res.cookie('_dup', 'three', { path: '/' });
        res.send('');
      });

      browser.deleteCookies();
      await browser.visit('/cookies2');
      await browser.visit('/cookies3');
    });

    it('should retain last value', function() {
      browser.assert.cookie('_dup', 'three');
    });
    it('should only retain last cookie', function() {
      assert.equal(browser.cookies.length, 1);
    });
  });


  describe('send cookies', function() {
    let cookies;

    before(async function() {
      browser.deleteCookies();
      browser.setCookie({ domain: 'example.com',                            name: '_name',                       value: 'value' });
      browser.setCookie({ domain: 'example.com',                            name: '_expires1',  'max-age': 3000, value: '3s' });
      browser.setCookie({ domain: 'example.com',                            name: '_expires2',  'max-age': 0,    value: '0s' });
      browser.setCookie({ domain: 'example.com',    path: '/cookies',       name: '_path1',                      value: 'here' });
      browser.setCookie({ domain: 'example.com',    path: '/cookies/echo',  name: '_path2',                      value: 'here' });
      browser.setCookie({ domain: 'example.com',    path: '/jars',          name: '_path3',                      value: 'there' });
      browser.setCookie({ domain: 'example.com',    path: '/cookies/fido',  name: '_path4',                      value: 'there' });
      browser.setCookie({ domain: 'example.com',    path: '/',              name: '_path5',                      value: 'here' });
      browser.setCookie({ domain: '.example.com',                           name: '_domain1',                    value: 'here' });
      browser.setCookie({ domain: 'not.example.com',                        name: '_domain2',                    value: 'there' });
      browser.setCookie({ domain: 'notexample.com',                         name: '_domain3',                    value: 'there' });
      await browser.visit('/cookies/echo');
      cookies = cookiesFromHtml(browser);
    });

    it('should send session cookie', function() {
      assert.equal(cookies._name, 'value');
    });
    it('should pass persistent cookie to server', function() {
      assert.equal(cookies._expires1, '3s');
    });
    it('should not pass expired cookie to server', function() {
      assert.equal(cookies._expires2, null);
    });
    it('should pass path cookies to server', function() {
      assert.equal(cookies._path1, 'here');
      assert.equal(cookies._path2, 'here');
      assert.equal(cookies._path5, 'here');
    });
    it('should not pass unrelated path cookies to server', function() {
      assert.equal(cookies._path3, null, 'path3');
      assert.equal(cookies._path4, null, 'path4');
      assert.equal(cookies._path6, null, 'path5');
    });
    it('should pass sub-domain cookies to server', function() {
      assert.equal(cookies._domain1, 'here');
    });
    it('should not pass other domain cookies to server', function() {
      assert.equal(cookies._domain2, null);
      assert.equal(cookies._domain3, null);
    });
  });


  describe('setting cookies from subdomains', function() {
    before(function() {
      browser.deleteCookies();
      browser.cookies.update('foo=bar; domain=example.com');
    });

    it('should be accessible', function() {
      browser.assert.cookie({ domain: 'example.com', name: 'foo' }, 'bar');
      browser.assert.cookie({ domain: 'www.example.com', name: 'foo' }, 'bar');
    });
  });


  // -- Access from JS --

  describe('document.cookie', function() {

    describe('setting cookie', function() {
      before(async function() {
        await browser.visit('/cookies');
        browser.document.cookie = 'foo=bar';
      });

      it('should be available from document', function() {
        assert(~browser.document.cookie.split('; ').indexOf('foo=bar'));
      });

      describe('on reload', function() {
        before(function() {
          return browser.visit('/cookies/echo');
        });

        it('should send to server', function() {
          const cookies = cookiesFromHtml(browser);
          assert.equal(cookies.foo, 'bar');
        });
      });

      describe('different path', function() {
        before(async function() {
          await browser.visit('/cookies');
          browser.document.cookie = 'foo=bar; path=/cookies';

          await browser.visit('/cookies/invalid');
          browser.document.cookie = 'foo=qux; path=/cookies/invalid'; // more specific path, not visible to /cookies.echo

          await browser.visit('/cookies/echo');
        });

        it('should not be visible', function() {
          const cookies = cookiesFromHtml(browser);
          assert(!cookies.bar);
          assert.equal(cookies.foo, 'bar');
        });
      });
    });


    describe('setting cookie with quotes', function() {
      before(async function() {
        await browser.visit('/cookies/empty');
        browser.document.cookie = 'foo=bar\'baz';
      });

      it('should be available from document', function() {
        browser.assert.cookie('foo', 'bar\'baz');
      });
    });


    describe('setting cookie with semicolon', function() {
      before(async function() {
        await browser.visit('/cookies/empty');
        browser.document.cookie = 'foo=bar; baz';
      });

      it('should be available from document', function() {
        browser.assert.cookie('foo', 'bar');
      });
    });
  });


  after(function() {
    browser.destroy();
  });
});

