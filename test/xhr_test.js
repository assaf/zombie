const assert      = require('assert');
const Browser     = require('../src/zombie');
const { brains }  = require('./helpers');
const thirdParty  = require('./helpers/thirdparty');


describe('XMLHttpRequest', function() {
  let browser;

  before(function() {
    browser = Browser.create();
    return brains.ready();
  });


  describe('asynchronous', function() {
    before(function() {
      brains.static('/xhr/async', `
        <html>
          <head><script src='/scripts/jquery.js'></script></head>
          <body>
            <script>
              document.title = 'One';
              window.foo = 'bar';
              $.get('/xhr/async/backend', function(response) {
                window.foo += window.foo;
                document.title += response;
              });
              document.title += 'Two';
            </script>
          </body>
        </html>`);
      brains.static('/xhr/async/backend', 'Three');
      return browser.visit('/xhr/async');
    });

    it('should load resource asynchronously', function() {
      browser.assert.text('title', 'OneTwoThree');
    });
    it('should run callback in global context', function() {
      browser.assert.global('foo', 'barbar');
    });
  });


  describe('response headers', function() {
    before(function() {
      brains.static('/xhr/headers', `
        <html>
          <head><script src='/scripts/jquery.js'></script></head>
          <body>
            <script>
              $.get('/xhr/headers/backend', function(data, textStatus, jqXHR) {
                document.allHeaders = jqXHR.getAllResponseHeaders();
                document.headerOne = jqXHR.getResponseHeader('Header-One');
                document.headerThree = jqXHR.getResponseHeader('header-three');
              });
            </script>
          </body>
        </html>`);
      brains.get('/xhr/headers/backend', function(req, res) {
        res.setHeader('Header-One', 'value1');
        res.setHeader('Header-Two', 'value2');
        res.setHeader('Header-Three', 'value3');
        res.send('');
      });
      return browser.visit('/xhr/headers');
    });

    it('should return all headers as string', function() {
      assert(~browser.document.allHeaders.indexOf('header-one: value1\nheader-two: value2\nheader-three: value3'));
    });
    it('should return individual headers', function() {
      assert.equal(browser.document.headerOne,   'value1');
      assert.equal(browser.document.headerThree, 'value3');
    });
  });


  describe('cookies', function() {
    before(function() {
      brains.get('/xhr/cookies', function(req, res) {
        res.cookie('xhr', 'send', { path: '/xhr' });
        res.send(`
          <html>
            <head><script src='/scripts/jquery.js'></script></head>
            <body>
              <script>
                $.get('/xhr/cookies/backend', function(cookie) {
                  document.received = cookie;
                });
              </script>
            </body>
          </html>`);
      });
      brains.get('/xhr/cookies/backend', function(req, res) {
        const cookie = req.cookies.xhr;
        res.cookie('xhr', 'return', { path: '/xhr' });
        res.send(cookie);
      });
      return browser.visit('/xhr/cookies');
    });

    it('should send cookies to XHR request', function() {
      assert.equal(browser.document.received, 'send');
    });
    it('should return cookies from XHR request', function() {
      assert(/xhr=return/.test(browser.document.cookie));
    });
  });


  describe('redirect', function() {
    before(function() {
      brains.static('/xhr/redirect', `
        <html>
          <head><script src='/scripts/jquery.js'></script></head>
          <body>
            <script>
              $.get('/xhr/redirect/backend', function(response) { window.response = response });
            </script>
          </body>
        </html>`);
      brains.redirect('/xhr/redirect/backend', '/xhr/redirect/target');
      brains.get('/xhr/redirect/target', function(req, res) {
        res.send('redirected ' + req.headers['x-requested-with']);
      });
      return browser.visit('/xhr/redirect');
    });

    it('should follow redirect', function() {
      assert(/redirected/.test(browser.window.response));
    });
    it('should resend headers', function() {
      assert(/XMLHttpRequest/.test(browser.window.response));
    });
  });


  describe('handle POST requests with no data', function() {
    before(function() {
      brains.static('/xhr/post/empty', `
        <html>
          <head><script src='/scripts/jquery.js'></script></head>
          <body>
            <script>
              $.post('/xhr/post/empty', function(response, status, xhr) { document.title = xhr.status + response });
            </script>
          </body>
        </html>`);
      brains.post('/xhr/post/empty', function(req, res) {
        res.status(201).send('posted');
      });
      return browser.visit('/xhr/post/empty');
    });

    it('should post with no data', function() {
      browser.assert.text('title', '201posted');
    });
  });


  describe('empty response', function() {
    before(function() {
      brains.static('/xhr/get-empty', `
        <html>
          <head><script src='/scripts/jquery.js'></script></head>
          <body>
            <script>
              $.get('/xhr/empty', function(response, status, xhr) {
                document.text = xhr.responseText;
              });
            </script>
          </body>
        </html>`);
      brains.static('/xhr/empty', '');
      return browser.visit('/xhr/get-empty');
    });

    it('responseText should be an empty string', function() {
      assert.strictEqual('', browser.document.text);
    });
  });


  describe('response text', function() {
    before(function() {
      brains.static('/xhr/get-utf8-octet-stream', `
        <html>
          <head><script src='/scripts/jquery.js'></script></head>
          <body>
            <script>
              $.get('/xhr/utf8-octet-stream', function(response, status, xhr) {
                document.text = xhr.responseText;
              });
            </script>
          </body>
        </html>`);
      brains.get('/xhr/utf8-octet-stream', function(req, res) {
        res.type('application/octet-stream');
        res.send('Text');
      });
      return browser.visit('/xhr/get-utf8-octet-stream');
    });

    it('responseText should be a string', function() {
      assert.equal(typeof(browser.document.text), 'string');
      assert.equal(browser.document.text, 'Text');
    });
  });


  describe('xhr onreadystatechange', function() {
    before(function() {
      brains.static('/xhr/get-onreadystatechange', `
        <html>
          <head></head>
          <body>
            <script>
              document.readyStatesReceived = { 1:[], 2:[], 3:[], 4:[] };
              var xhr = new XMLHttpRequest();
              xhr.onreadystatechange = function(){
                document.readyStatesReceived[xhr.readyState].push(Date.now())
              };
              xhr.open('GET', '/xhr/onreadystatechange', true);
              xhr.send();
            </script>
          </body>
        </html>`);
      brains.static('/xhr/onreadystatechange', 'foo');
      return browser.visit('/xhr/get-onreadystatechange');
    });

    it('should get exactly one readyState of type 1, 2, and 4', function() {
      assert.equal(browser.document.readyStatesReceived[1].length, 1);
      assert.equal(browser.document.readyStatesReceived[2].length, 1);
      assert.equal(browser.document.readyStatesReceived[4].length, 1);
    });

    it('should get the readyStateChanges in chronological order', function() {
      assert(browser.document.readyStatesReceived[1][0] <=
             browser.document.readyStatesReceived[2][0]);
      assert(browser.document.readyStatesReceived[2][0] <=
             browser.document.readyStatesReceived[4][0]);
    });

  });

  describe('xhr onreadystatechange errors', function() {
    before(function() {
      brains.static('/xhr/get-onreadystatechange-error', `
        <html>
          <head></head>
          <body>
            <script>
              document.readyStatesReceived = { 1:[], 2:[], 3:[], 4:[] };
              document.onloadTime = null;
              document.responseText = { 1:null, 4:null};
              var xhr = new XMLHttpRequest();
              xhr.onreadystatechange = function(){
                document.readyStatesReceived[xhr.readyState].push(Date.now())
                document.responseText[xhr.readyState] = xhr.responseText;
              };
              xhr.onload = function() {
                  document.onloadTime = Date.now()
              }
              xhr.open('GET', '/xhr/onreadystatechange-error', true);
              xhr.send();
            </script>
          </body>
        </html>`);
      browser.resources.fail('/xhr/onreadystatechange-error');
      return browser.visit('/xhr/get-onreadystatechange-error')
        .catch(function(error) {
          assert.equal(error.message, 'This request was intended to fail');
        })
        .then(function () {
          return browser.wait();
        });
    });

    it('should not trigger onload to be called', function() {
      assert.equal(browser.document.onloadTime, null);
    });

    it('responseText should be empty on error', function() {
        assert.equal(browser.document.responseText[4], "");
    });

    it('should get exactly one readyState of type 1 and 4', function() {
      assert.equal(browser.document.readyStatesReceived[1].length, 1, 'state 1');
      assert.equal(browser.document.readyStatesReceived[2].length, 0, 'state 2');
      assert.equal(browser.document.readyStatesReceived[3].length, 0, 'state 3');
      assert.equal(browser.document.readyStatesReceived[4].length, 1, 'state 4');
    });

    it('should get the readyStateChanges in chronological order', function() {
      assert(browser.document.readyStatesReceived[1][0] <=
             browser.document.readyStatesReceived[4][0]);
    });

  });


  describe.skip('HTML document', function() {
    before(function() {
      brains.static('/xhr/get-html', `
        <html>
          <head><script src='/scripts/jquery.js'></script></head>
          <body>
            <script>
              $.get('/xhr/html', function(response, status, xhr) {
                document.body.appendChild(xhr.responseXML);
              });
            </script>
          </body>
        </html>`);
      brains.get('/xhr/html', function(req, res) {
        res.type('text/html');
        res.send('<foo><bar id="bar"></foo>');
      });
      return browser.visit('/xhr/get-html');
    });

    it('should parse HTML document', function() {
      browser.assert.element('foo > bar#bar');
    });
  });

  
  describe('CORS', function() {

    before(function() {
      brains.static('/cors/:path', `
        <html>
          <body>
            <script>
              var path = document.location.pathname.split('/')[2];
              var xhr = new XMLHttpRequest();
              xhr.onerror = function() {
                document.title = 'error';
              };
              xhr.onload = function() {
                document.title = xhr.responseText;
              };
              xhr.open('GET', '//thirdparty.test/' + path);
              xhr.send();
            </script>
          </body>
        </html>`);
    });

    describe('no access control header', function() {
      before(async function() {
        const cors = await thirdParty();
        cors.get('/no-access-header', function(req, res) {
          res.send('No-access-header'); // We'll get error instead
        });
      });

      it('should fail', async function() {
        try {
          await browser.visit('/cors/no-access');
        } catch (error) {
          browser.assert.text('title', 'error');
          return;
        }
        assert(false, 'Error not propagated to window');
      });
    });

    describe('access to *', function() {
      before(async function() {
        const cors = await thirdParty();
        cors.get('/access-star', function(req, res) {
          res.header('Access-Control-Allow-Origin', '*');
          res.send('Access *');
        });
      });

      it('should allow access', async function() {
        await browser.visit('/cors/access-star');
        browser.assert.text('title', 'Access *');
      });
    });

    describe('access to origin', function() {
      before(async function() {
        const cors = await thirdParty();
        cors.get('/access-origin', function(req, res) {
          assert.equal(req.headers.origin, 'http://example.com');
          res.header('Access-Control-Allow-Origin', 'http://example.com');
          res.send('Access http://example.com');
        });
      });

      it('should allow access', async function() {
        await browser.visit('/cors/access-origin');
        browser.assert.text('title', 'Access http://example.com');
      });
    });

    describe('access other', function() {
      before(async function() {
        const cors = await thirdParty();
        cors.get('/access-other', function(req, res) {
          res.header('Access-Control-Allow-Origin', 'http://other.com');
          res.send('Access http://other.com');
        });
      });

      it('should fail', async function() {
        try {
          await browser.visit('/cors/access-other');
        } catch (error) {
          browser.assert.text('title', 'error');
          return;
        }
        assert(false, 'Error not propagated to window');
      });
    });

  });

  describe('error in response handler', function() {
    before(function() {
      brains.static('/xhr/handler-error', `
        <html>
          <head><script src='/scripts/jquery.js'></script></head>
          <body>
            <script>
              $.get('/xhr/handler-error/backend', function(response) {
                throw new Error('This is an error');
              });
            </script>
          </body>
        </html>`);
      brains.static('/xhr/handler-error/backend', 'Something');
    });

    it('should throw the error in the response handler', function(done) {
      browser.visit('/xhr/handler-error').then(
        function() {
          done(new Error('Expected to see error in ajax response handler'));
        },
        function(error) {
          assert.strictEqual(
            error.message,
            'This is an error',
            'Expected to see error in ajax response handler'
          );
          done();
        });
    });
  });


  after(function() {
    browser.destroy();
  });
});
