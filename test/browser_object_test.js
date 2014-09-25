const assert      = require('assert');
const Browser     = require('../src/zombie');
const { brains }  = require('./helpers');
const JSDOM       = require('jsdom');


describe("Browser", function() {
  let browser;

  before(function() {
    browser = Browser.create();

    brains.static('/browser/scripted', `
      <html>
        <head>
          <title>Whatever</title>
          <script src='/jquery.js'></script>
        </head>
        <body>
          <h1>Hello World</h1>
          <script>
            document.title = 'Nice';
            $(function() { $('title').text('Awesome') })
          </script>
          <script type='text/x-do-not-parse'>
            <p>this is not valid JavaScript</p>
          </script>
        </body>
      </html>
    `);

    brains.static('/browser/errored', `
      <html>
        <head>
          <script>this.is.wrong</script>
        </head>
      </html>
    `);

    return brains.ready();
  });


  describe("browsing", function() {

    describe("open page", function() {
      before(function() {
        return browser.visit('/browser/scripted');
      });

      it("should create HTML document", function() {
        assert(browser.document instanceof JSDOM.level(3, 'html').HTMLDocument);
      });
      it("should load document from server", function() {
        browser.assert.text('body h1', "Hello World");
      });
      it("should load external scripts", function() {
        let jQuery = browser.window.jQuery;
        assert(jQuery, "window.jQuery not available");
        assert.equal(typeof(jQuery.ajax), 'function');
      });
      it("should run jQuery.onready", function() {
        browser.assert.text('title', "Awesome");
      });
      it("should return status code of last request", function() {
        browser.assert.success();
      });
      it("should indicate success", function() {
        assert(browser.success);
      });
      it("should have a parent", function() {
        assert(browser.window.parent);
      });
    });


    describe("visit", function() {

      describe("successful", function() {
        let callbackBrowser;

        before(async function() {
          callbackBrowser = await Browser.visit('/browser/scripted');
        });

        it("should pass browser to callback", function() {
          assert(callbackBrowser instanceof Browser);
        });
        it("should pass status code to callback", function() {
          callbackBrowser.assert.success();
        });
        it("should indicate success", function() {
          assert(callbackBrowser.success);
        });
        it("should reset browser errors", function() {
          assert.equal(callbackBrowser.errors.length, 0);
        });
        it("should have a resources object", function() {
          assert(callbackBrowser.resources);
        });
      });

      describe("with error", function() {
        let error;

        before(async function() {
          try {
            await browser.visit('/browser/errored');
            assert(false, "Should have errored");
          } catch (callbackError) {
            error = callbackError;
          }
        });

        it("should call callback with error", function() {
          assert.equal(error.constructor.name, 'TypeError');
        });
        it("should indicate success", function() {
          browser.assert.success();
        });
        it("should set browser errors", function() {
          assert.equal(browser.errors.length, 1);
          assert.equal(browser.errors[0].message, "Cannot read property 'wrong' of undefined");
        });
      });

      describe("404", function() {
        let error;

        before(async function() {
          try {
            await browser.visit('/browser/missing');
            assert(false, "Should have errored");
          } catch (callbackError) {
            error = callbackError;
          }
        });

        it("should call with error", function() {
          assert(error instanceof Error);
        });
        it("should return status code", function() {
          browser.assert.status(404);
        });
        it("should not indicate success", function() {
          assert(!browser.success);
        });
        it("should capture response document", function() {
          assert.equal(browser.source.trim(), "Cannot GET /browser/missing"); // Express output
        });
        it("should return response document with the error", function() {
          browser.assert.text('body', "Cannot GET /browser/missing"); // Express output
        });
      });

      describe("500", function() {
        let error;

        before(async function() {
          brains.static('/browser/500', "Ooops, something went wrong", { status: 500 });

          try {
            await browser.visit('/browser/500');
            assert(false, "Should have errored");
          } catch (callbackError) {
            error = callbackError;
          }
        });

        it("should call callback with error", function() {
          assert(error instanceof Error);
        });
        it("should return status code 500", function() {
          browser.assert.status(500);
        });
        it("should not indicate success", function() {
          assert(!browser.success);
        });
        it("should capture response document", function() {
          assert.equal(browser.source, "Ooops, something went wrong");
        });
        it("should return response document with the error", function() {
          browser.assert.text('body', "Ooops, something went wrong");
        });
      });

      describe("empty page", function() {
        before(function() {
          brains.static('/browser/empty', "");
          return browser.visit('/browser/empty');
        });

        it("should load document", function() {
          assert(browser.body);
        });
        it("should indicate success", function() {
          browser.assert.success();
        });
      });

    });


    describe("event emitter", function() {

      describe("successful", function() {
        it("should fire load event with document object", async function() {
          var document;
          browser.once('loaded', function(arg) {
            document = arg;
          });
          await browser.visit('/browser/scripted');
          assert(document.addEventListener);
        });
      });

      describe("wait over", function() {
        it("should fire done event", function(done) {
          var done;
          browser.once('done', done);
            done = true;
          browser.location = '/browser/scripted';
          browser.wait();
        });
      });

      describe("error", function() {
        it("should fire onerror event with error", async function() {
          var error;
          browser.once('error', function(arg) {
            error = arg;
          });
          browser.location = '/browser/errored';
          try {
            await browser.wait();
          } catch (error) { }

          assert(error.message && error.stack);
          assert.equal(error.message, "Cannot read property 'wrong' of undefined");
        });
      });

    });

  });


  describe("with options", function() {

    describe("per call", function() {
      before(function() {
        return browser.visit('/browser/scripted', { features: 'no-scripts' });
      });

      it("should set options for the duration of the request", function() {
        browser.assert.text('title', "Whatever");
      });
      it("should reset options following the request", function() {
        assert.equal(browser.features, 'scripts no-css no-img iframe');
      });
    });

    describe("global", function() {
      let newBrowser;
      let originalFeatures;

      before(function() {
        originalFeatures = Browser.default.features;
        Browser.default.features = 'no-scripts';
        newBrowser = Browser.create();
        return newBrowser.visit('/browser/scripted');
      });

      it("should set browser options from global options", function() {
        newBrowser.assert.text('title', "Whatever");
      });

      after(function() {
        newBrowser.destroy();
        Browser.default.features = originalFeatures;
      });
    });

    describe("user agent", function() {
      before(function() {
        brains.get('/browser/useragent', function(req, res) {
          res.send("<html><body>" + req.headers['user-agent'] + "</body></html>");
        });
        return browser.visit('/browser/useragent');
      });

      it("should send own version to server", function() {
        browser.assert.text('body', /Zombie.js\/\d\.\d/);
      });
      it("should be accessible from navigator", function() {
        assert(/Zombie.js\/\d\.\d/.test(browser.window.navigator.userAgent));
      });

      describe("specified", function() {
        before(function() {
          return browser.visit('/browser/useragent', { userAgent: 'imposter' });
        });

        it("should send user agent to server", function() {
          browser.assert.text('body', "imposter");
        });
        it("should be accessible from navigator", function() {
          assert.equal(browser.window.navigator.userAgent, "imposter");
        });
      });
    });

    describe("custom headers", function() {
      before(function() {
        brains.get('/browser/custom_headers', function(req, res) {
          res.send("<html><body>" + req.headers['x-custom-header'] + "</body></html>");
        });
        browser.headers = {
          "x-custom-header": "dummy"
        };
        return browser.visit('/browser/custom_headers');
      });


      it("should send the custom header to server", function() {
        browser.assert.text('body', "dummy");
      });

      after(function() {
        delete browser.headers['x-custom-header'];
      });
    });

  });


  describe("click link", function() {
    before(async function() {
      brains.static('/browser/head', `
        <html>
          <body>
            <a href='/browser/headless'>Smash</a>
          </body>
        </html>
      `);
      brains.static('/browser/headless', `
        <html>
          <head>
            <script src='/jquery.js'></script>
          </head>
          <body>
            <script>
              $(function() { document.title = 'The Dead' });
            </script>
          </body>
        </html>
      `);

      await browser.visit('/browser/head');
      await browser.clickLink('Smash');
    });

    it("should change location", function() {
      browser.assert.url('/browser/headless');
    });
    it("should run all events", function() {
      browser.assert.text('title', "The Dead");
    });
    it("should return status code", function() {
      browser.assert.success();
    });
  });


  describe("click link text", function() {
    before(async function() {
      brains.static('/browser/linktext', `
        <html>
          <body>
            <a href='/browser/linktextlocation'>not valid CSS selector syntax..</a>
          </body>
        </html>
      `);
      brains.static('/browser/linktextlocation', `
        <html>
          <head>
          </head>
          <body>
          </body>
        </html>
      `);

      await browser.visit('/browser/linktext');
      await browser.clickLink('not valid CSS selector syntax..');
    });

    it("should change location", function() {
      browser.assert.url('/browser/linktextlocation');
    });
  });


  describe("follow redirect", function() {
    before(async function() {
      brains.static('/browser/killed', `
        <html>
          <body>
            <form action='/browser/alive' method='post'>
              <input type='submit' name='Submit'>
            </form>
          </body>
        </html>
      `);
      brains.post('/browser/alive', function(req, res) {
        res.redirect('/browser/killed');
      });

      await browser.visit('/browser/killed');
      await browser.pressButton('Submit');
    });

    it("should be at initial location", function() {
      browser.assert.url('/browser/killed');
    });
    it("should have followed a redirection", function() {
      browser.assert.redirected();
    });
    it("should return status code", function() {
      browser.assert.success();
    });
  });


  describe("tag soup using HTML5 parser", function() {
    before(function() {
      brains.static('/browser/soup', `
        <h1>Tag soup</h1>
        <p>One paragraph
        <p>And another
      `);
      return browser.visit('/browser/soup');
    });

    it("should parse to complete HTML", function() {
      browser.assert.element('html head');
      browser.assert.text('html body h1', "Tag soup");
    });
    it("should close tags", function() {
      browser.assert.text('body p', "One paragraph And another");
    });
  });


  describe("comments", function() {
    it("should not show up as text node", async function() {
      brains.static('/browser/comment', "This is <!-- a comment, not --> plain text");
      await browser.visit('/browser/comment');

      browser.assert.text('body', "This is plain text");
    });
  });


  describe("load HTML string", function() {
    before(function() {
      browser.load(`
        <html>
          <head>
            <title>Load</title>
          </head>
          <body>
            <div id='main'></div>
            <script>document.title = document.title + ' html'</script>
          </body>
        </html>
      `);
    });

    it("should use about:blank URL", function() {
      browser.assert.url('about:blank');
    });
    it("should load document", function() {
      browser.assert.element('#main');
    });
    it("should execute JavaScript", function() {
      browser.assert.text('title', "Load html");
    });
  });


  describe("multiple visits to same URL", function() {
    it("should load document from server", async function() {
      await browser.visit('/browser/scripted');
      browser.assert.text('body h1', "Hello World");

      await browser.visit('/');
      browser.assert.text('title', "Tap, Tap");

      await browser.visit('/browser/scripted');
      browser.assert.text('body h1', "Hello World");
    });
  });


  describe("windows", function() {

    describe("open window to page", function() {
      let window;

      before(async function() {
        brains.static('/browser/popup', "<h1>Popup window</h1>");
          
        browser.tabs.closeAll();
        await browser.visit('about:blank');
        window = browser.window.open('http://example.com/browser/popup', 'popup');
        await browser.wait();
      });

      it("should create new window", function() {
        assert(window);
      });
      it("should set window name", function() {
        assert.equal(window.name, 'popup');
      });
      it("should set window closed to false", function() {
        assert.equal(window.closed, false);
      });
      it("should load page", function() {
        browser.assert.text('h1', "Popup window");
      });


      describe("call open on named window", function() {
        let named;

        before(function() {
          named = browser.window.open(null, 'popup');
        });

        it("should return existing window", function() {
          assert.equal(named, window);
        });
        it("should not change document location", function() {
          assert.equal(named.location.href, 'http://example.com/browser/popup');
        });
      });
    });

    describe("open one window from another", function() {
      before(function() {
        brains.static('/browser/pop', `
          <script>
            document.title = window.open('/browser/popup', 'popup')
          </script>
        `);
        brains.static('/browser/popup', "<h1>Popup window</h1>");

        browser.tabs.closeAll();
        return browser.visit('/browser/pop');
      });

      it("should open both windows", function() {
        assert.equal(browser.tabs.length, 2);
        assert.equal(browser.tabs[0].name, '');
        assert.equal(browser.tabs[1].name, 'popup');
      });

      it("should switch to last window", function() {
        assert.equal(browser.window, browser.tabs[1]);
      });

      it("should reference opener from opened window", function() {
        assert.equal(browser.window.opener, browser.tabs[0]);
      });


      describe("and close it", function() {
        let closedWindow;

        before(function() {
          closedWindow = browser.window;
          browser.window.close();
        });

        it("should close that window", function() {
          assert.equal(browser.tabs.length, 1);
          assert.equal(browser.tabs[0].name, '');
          assert(!browser.tabs[1]);
        });

        it("should set the `closed` property to `true`", function() {
          assert.equal(closedWindow.closed, true);
        });

        it("should switch to last window", function() {
          assert.equal(browser.window, browser.tabs[0]);
        });


        describe("and close main window", function() {
          before(function() {
            browser.open();
            browser.window.close();
          });

          it("should keep that window", function() {
            assert.equal(browser.tabs.length, 1);
            assert.equal(browser.tabs[0].name, '');
            assert.equal(browser.window, browser.tabs[0]);
          });

          describe("and close browser", function() {
            it("should close all window", function() {
              assert.equal(browser.tabs.length, 1);
              browser.close();
              assert.equal(browser.tabs.length, 0);
            });
          });
        });
      });
    });

  });


  describe("fork", function() {
    let forked;

    before(async function() {
      brains.static('/browser/living', "<html><script>dead = 'almost'</script></html>");
      brains.static('/browser/dead', "<html><script>dead = 'very'</script></html>");
        
      await browser.visit('/browser/living');
      browser.setCookie({ name: 'foo', value: 'bar' });
      browser.localStorage('www.example.com').setItem('foo', 'bar');
      browser.sessionStorage('www.example.com').setItem('baz', 'qux');
      forked = browser.fork();

      await forked.visit('/browser/dead');
      forked.setCookie({ name: 'foo', value: 'baz' });
      forked.localStorage('www.example.com').setItem('foo', 'new');
      forked.sessionStorage('www.example.com').setItem('baz', 'value');
    });

    it("should have two browser objects", function() {
      assert(forked && browser);
      assert(browser != forked);
    });
    it("should use same options", function() {
      assert.equal(browser.debug,       forked.debug);
      assert.equal(browser.htmlParser,  forked.htmlParser);
      assert.equal(browser.maxWait,     forked.maxWait);
      assert.equal(browser.proxy,       forked.proxy);
      assert.equal(browser.referer,     forked.referer);
      assert.equal(browser.features,    forked.features);
      assert.equal(browser.silent,      forked.silent);
      assert.equal(browser.site,        forked.site);
      assert.equal(browser.userAgent,   forked.userAgent);
      assert.equal(browser.waitFor,     forked.waitFor);
      assert.equal(browser.name,        forked.name);
    });
    it("should navigate independently", function() {
      assert.equal(browser.location.href, 'http://example.com/browser/living');
      assert.equal(forked.location, 'http://example.com/browser/dead');
    });
    it("should manipulate cookies independently", function() {
      assert.equal(browser.getCookie({ name: 'foo' }), 'bar');
      assert.equal(forked.getCookie({ name: 'foo' }), 'baz');
    });
    it("should manipulate storage independently", function() {
      assert.equal(browser.localStorage('www.example.com').getItem('foo'), 'bar');
      assert.equal(browser.sessionStorage('www.example.com').getItem('baz'), 'qux');
      assert.equal(forked.localStorage('www.example.com').getItem('foo'), 'new');
      assert.equal(forked.sessionStorage('www.example.com').getItem('baz'), 'value');
    });
    it("should have independent history", function() {
      assert.equal('http://example.com/browser/living', browser.location.href);
      assert.equal('http://example.com/browser/dead', forked.location.href);
    });
    it("should have independent globals", function() {
      assert.equal(browser.evaluate('window.dead'), "almost");
      assert.equal(forked.evaluate('window.dead'), "very");
    });

    describe.skip("history", function() {
      it("should clone from source", function() {
        assert.equal('http://example.com/browser/dead', forked.location.href);
        forked.window.history.back();
        assert.equal('http://example.com/browser/living', forked.location.href);
      });
    });
  });


  after(function() {
    browser.destroy();
  });
});

