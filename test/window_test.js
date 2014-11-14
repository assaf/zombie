const assert      = require('assert');
const Browser     = require('../src/zombie');
const { brains }  = require('./helpers');


describe('Window', function() {
  let browser;

  before(function() {
    browser = Browser.create();
    return brains.ready();
  });

  // -- Alert, confirm and popup; form when we let browsers handle our UI --

  describe('.alert', function() {
    before(async function() {
      brains.static('/window/alert', `
        <html>
          <script>
            alert("Hi");
            alert("Me again");
          </script>
        </html>
      `);
      browser.onalert(function(message) {
        browser.window.promptedWith = message;
      });
      browser.visit('/window/alert');
    });

    it('should record last alert show to user', function() {
      browser.assert.prompted('Me again');
    });
    it('should call onalert function with message', function() {
      assert.equal(browser.window.promptedWith, 'Me again');
    });
  });

  describe('.confirm', function() {
    before(async function() {
      brains.static('/window/confirm', `
        <html>
          <script>
            window.first = confirm("continue?");
            window.second = confirm("more?");
            window.third = confirm("silent?");
          </script>
        </html>
      `);
      browser.onconfirm('continue?', true);
      browser.onconfirm((prompt)=> prompt === 'more?');
      await browser.visit('/window/confirm');
    });

    it('should return canned response', function() {
      assert(browser.window.first);
    });
    it('should return response from function', function() {
      assert(browser.window.second);
    });
    it('should return false if no response/function', function() {
      assert.equal(browser.window.third, false);
    });
    it('should report prompted question', function() {
      browser.assert.prompted('continue?');
      browser.assert.prompted('silent?');
      assert(!browser.prompted('missing?'));
    });
  });


  describe('.prompt', function() {
    before(async function() {
      brains.static('/window/prompt', `
        <html>
          <script>
            window.first = prompt("age");
            window.second = prompt("gender");
            window.third = prompt("location");
            window.fourth = prompt("weight");
          </script>
        </html>
      `);
      browser.onprompt('age', 31);
      browser.onprompt((message, def)=> message === 'gender' ? 'unknown' : undefined);
      browser.onprompt('location', false);
      await browser.visit('/window/prompt');
    });

    it('should return canned response', function() {
      assert.equal(browser.window.first, '31');
    });
    it('should return response from function', function() {
      assert.equal(browser.window.second, 'unknown');
    });
    it('should return null if cancelled', function() {
      assert.equal(browser.window.third, null);
    });
    it('should return empty string if no response/function', function() {
      assert.equal(browser.window.fourth, '');
    });
    it('should report prompts', function() {
      browser.assert.prompted('age');
      browser.assert.prompted('gender');
      browser.assert.prompted('location');
      assert(!browser.prompted('not asked'));
    });
  });


  // -- This part deals with various windows properties ---

  describe('.title', function() {
    before(async function() {
      brains.static('/window/title', `
        <html>
          <head>
            <title>Whatever</title>
          </head>
          <body>Hello World</body>
        </html>
      `);
      await browser.visit('/window/title');
    });

    it('should return the document title', function() {
      browser.assert.text('title', 'Whatever');
    });
    it('should set the document title', function() {
      browser.window.title = 'Overwritten';
      assert.equal(browser.window.title, browser.document.title);
    });
  });


  describe('.screen', function() {
    it('should have a screen object available', function() {
      browser.assert.evaluate('screen.width',       1280);
      browser.assert.evaluate('screen.height',      800);
      browser.assert.evaluate('screen.left',        0);
      browser.assert.evaluate('screen.top',         0);
      browser.assert.evaluate('screen.availLeft',   0);
      browser.assert.evaluate('screen.availTop',    0);
      browser.assert.evaluate('screen.availWidth',  1280);
      browser.assert.evaluate('screen.availHeight', 800);
      browser.assert.evaluate('screen.colorDepth',  24);
      browser.assert.evaluate('screen.pixelDepth',  24);
    });
  });


  describe('.navigator', function() {
    before(async function() {
      brains.static('/window/navigator', `
        <html>
          <head>
            <title>Whatever</title>
          </head>
          <body>Hello World</body>
        </html>
      `);
      await browser.visit('/window/navigator');
    });

    it('should exist', function() {
      browser.assert.evaluate('navigator');
    });
    it('.javaEnabled should be false', function() {
      browser.assert.evaluate('navigator.javaEnabled()', false);
    });
    it('.language should be set to en-US', function() {
      browser.assert.evaluate('navigator.language', 'en-US');
    });
    it('.plugins should be empty array', function() {
      browser.assert.evaluate('navigator.plugins', []);
    });
  });

  describe('atob', function() {
    it('should decode base-64 string', function() {
      const window = browser.open();
      browser.assert.evaluate('atob("SGVsbG8sIHdvcmxk")', 'Hello, world');
    });
  });

  describe('btoa', function() {
    it('should encode base-64 string', function() {
      const window = browser.open();
      browser.assert.evaluate('btoa("Hello, world")', 'SGVsbG8sIHdvcmxk');
    });
  });

  describe('DataView', function () {
    it('should create a DataView', function () {
      const window = browser.open();
      assert.equal(window.DataView, DataView);
      browser.assert.evaluate('new DataView(new ArrayBuffer(8)).byteLength', '8');
    });
  });

  describe('onload', function() {
    before(async function() {
      brains.static('/windows/onload', `
        <html>
          <head>
            <title>The Title!</title>
            <script type="text/javascript" language="javascript" charset="utf-8">
              var about = function (e) {
                var info = document.getElementById('das_link');
                info.innerHTML = (parseInt(info.innerHTML) + 1) + ' clicks here';
                e.preventDefault();
                return false;
              }
              window.onload = function () {
                var info = document.getElementById('das_link');
                info.addEventListener('click', about, false);
              }
            </script>
          </head>
          <body>
            <a id="das_link" href="/no_js.html">0 clicks here</a>
          </body>
        </html>
      `);

      await browser.visit('/windows/onload');
      await browser.clickLink('#das_link');
    });

    it('should fire when document is done loading', function() {
      browser.assert.text('body', '1 clicks here');
    });
  });


  describe('refresh', function() {
    before(function() {
      brains.static('/windows/refreshed', `
        <html>
          <head>
            <title>Done</title>
          <body>Redirection complete.</body>
        </html>
      `);
      brains.get('/windows/refresh', function(req, res) {
        // Don't refresh page more than once
        const refresh = !req.headers.referer.endsWith('/windows/refresh');
        if (refresh) {
          const value = req.query.url ? `1; url=${req.query.url}` : '1'; // Refresh to URL or reload self
          res.send(`
            <html>
              <head>
                <title>Refresh</title>
                <meta http-equiv="refresh" content="${value}">
              </head>
              <body>
                You are being redirected.
              </body>
            </html>
          `);
        } else {
          res.send(`
            <html>
              <head><title>Done</title></head>
              <body></body>
            </html>
          `);
        }
      });
    });

    it('should follow a meta refresh to a relative URL', async function() {
      await browser.visit('/windows/refresh?url=/windows/refreshed');
      browser.assert.url('/windows/refreshed');
    });

    it('should follow a meta refresh to an absolute URL', async function() {
      await browser.visit('/windows/refresh?url=http://example.com/');
      browser.assert.url('http://example.com/');
    });

    it('should refresh the current page if no URL is given', async function() {
      await browser.visit('/windows/refresh');
      browser.assert.url('http://example.com/windows/refresh');
      browser.assert.text('title', 'Done');
    });

    it('should indicated that the last request was redirected', async function() {
      await browser.visit('/windows/refresh?url=/windows/refreshed')
      browser.assert.redirected();
    });

    it('should support testing the refresh page', async function() {
      function complete() {
        return browser.query('meta');
      }

      await browser.visit('/windows/refresh', { function: complete });
      browser.assert.url('http://example.com/windows/refresh');
      // Check the refresh page.
      browser.assert.text('title', 'Refresh');
      // Continue with refresh.
      await browser.wait();
      browser.assert.url('http://example.com/windows/refresh');
      browser.assert.text('title', 'Done');
    });

    afterEach(function() {
      browser.deleteCookies();
    })

  });


  describe('resize', function() {
    it('should change window dimensions', function() {
      const window = browser.open();
      assert.equal(window.innerWidth, 1024);
      assert.equal(window.innerHeight, 768);
      window.resizeBy(-224, -168);
      assert.equal(window.innerWidth, 800);
      assert.equal(window.innerHeight, 600);
    });
  });


  after(function() {
    browser.destroy();
  });
});
