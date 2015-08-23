const assert  = require('assert');
const brains  = require('./helpers/brains');
const Browser = require('../src');


describe('Window', function() {
  const browser = new Browser();

  before(function() {
    return brains.ready();
  });

  // -- Alert, confirm and popup; form when we let browsers handle our UI --

  describe('.alert', function() {
    let alert = null;

    before(async function() {
      brains.static('/window/alert', `
        <html>
          <script>
            alert("Hi");
            alert("Me again");
          </script>
        </html>
      `);
      browser.on('alert', function(message) {
        alert = message;
      });
      await browser.visit('/window/alert');
    });

    it('should emit alert event with message', function() {
      assert.equal(alert, 'Me again');
    });
  });

  describe('.confirm', function() {
    const questions = [];

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

      browser.on('confirm', function(confirm) {
        questions.push(confirm.question);
      });
      browser.on('confirm', function(confirm) {
        if (confirm.question === 'continue?')
          confirm.response = true;
      });
      browser.on('confirm', function(confirm) {
        if (confirm.question === 'more?')
          confirm.response = '';
      });

      await browser.visit('/window/confirm');
    });

    it('should emit confirm event with message', function() {
      assert.deepEqual(questions, ['continue?', 'more?', 'silent?']);
    });
    it('should return last response from event handler', function() {
      assert.equal(browser.window.first, true);
    });
    it('should convert response to boolean', function() {
      assert.equal(browser.window.second, false);
    });
    it('should default to return true', function() {
      assert.equal(browser.window.third, true);
    });
  });


  describe('.prompt', function() {
    const questions = [];

    before(async function() {
      brains.static('/window/prompt', `
        <html>
          <script>
            window.first = prompt("age");
            window.second = prompt("gender", "missing");
            window.third = prompt("location", "here");
            window.fourth = prompt("weight", 180);
          </script>
        </html>
      `);

      browser.on('prompt', function(prompt) {
        questions.push(prompt.question);
      });
      browser.on('prompt', function(prompt) {
        if (prompt.question === 'age')
          prompt.response = 31;
      });
      browser.on('prompt', function(prompt) {
        if (prompt.question === 'gender')
          prompt.response = 'unknown';
      });
      browser.on('prompt', function(prompt) {
        if (prompt.question === 'weight')
          prompt.response = false;
      });

      await browser.visit('/window/prompt');
    });

    it('should emit confirm event with message', function() {
      assert.deepEqual(questions, ['age', 'gender', 'location', 'weight']);
    });
    it('should return event handler response as string', function() {
      assert.equal(browser.window.first, '31');
    });
    it('should return last response from event handler', function() {
      assert.equal(browser.window.second, 'unknown');
    });
    it('should return default value if no response specified', function() {
      assert.equal(browser.window.third, 'here');
    });
    it('should return null if response if response is falsy', function() {
      assert.equal(browser.window.fourth, '');
    });
  });


  // -- This part deals with various windows properties ---

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
    it('javaEnabled should be false', function() {
      browser.assert.evaluate('navigator.javaEnabled()', false);
    });
    it('language should be set to en-US', function() {
      browser.assert.evaluate('navigator.language', 'en-US');
    });
    it('plugins should be empty array', function() {
      browser.assert.evaluate('navigator.plugins.length', 0);
    });
    it('plugins should have no items', function() {
      browser.assert.evaluate('navigator.plugins.item(0)', undefined);
      browser.assert.evaluate('navigator.plugins.namedItem("Flash")', undefined);
    });
    it('mimeTypes should be empty array', function() {
      browser.assert.evaluate('navigator.mimeTypes.length', 0);
    });
    it('mimeTypes should have no items', function() {
      browser.assert.evaluate('navigator.mimeTypes.item(0)', undefined);
      browser.assert.evaluate('navigator.mimeTypes.namedItem("Flash")', undefined);
    });
  });

  describe('atob', function() {
    it('should decode base-64 string', function() {
      browser.open();
      browser.assert.evaluate('atob("SGVsbG8sIHdvcmxk")', 'Hello, world');
    });
  });

  describe('btoa', function() {
    it('should encode base-64 string', function() {
      browser.open();
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
        const referrer  = req.headers.referer;
        const refreshed = referrer && referrer.endsWith('/windows/refresh');
        if (refreshed)
          res.send(`
            <html>
              <head><title>Done</title></head>
              <body></body>
            </html>
          `);
        else {
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
      await browser.visit('/windows/refresh?url=/windows/refreshed');
      browser.assert.redirected();
    });

    describe('meta refresh page', function() {

      before(async function() {
        browser.visit('/windows/refresh');

        function complete() {
          return !!browser.query('meta');
        }

        await browser.wait({ function: complete });
      });

      it('should check completion function on original page', function() {
        browser.assert.url('http://example.com/windows/refresh');
        // Check the refresh page.
        browser.assert.text('title', 'Refresh');
      });

      describe('continue', function() {
        before(function() {
          return browser.wait();
        });

        it('should continue to next page', function() {
          browser.assert.url('http://example.com/windows/refresh');
          browser.assert.text('title', 'Done');
        });
      });

    });


    afterEach(function() {
      browser.deleteCookies();
    });

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


  describe('getSelection', function(){
    before(function() {
      brains.static('/windows/getSelection', `
        <html>
          <head>
            <title>Whatever</title>
          </head>
          <body>
            <h1>Hello World</h1>
            <script>
              function logSelection() {
                  console.log(window.getSelection().toString());
              }
            </script>
            <button id="a-button" onclick="logSelection()"/>Log Selection</button>
          </body>
        </html>
      `);
      return brains.ready();
    });

    before(function(){
      return browser.visit('/windows/getSelection');
    });

    it('should not result in a browser error', function() {
      browser.click('#a-button');
      assert.equal(browser.errors.length, 0);
    });

    it('should not throw an error when evaluated directly', async function() {
      try {
        browser.evaluate('window.getSelection();');
      }
      catch (error) {
        throw new Error(error);
      }
    });

  });


  after(function() {
    browser.destroy();
  });
});
