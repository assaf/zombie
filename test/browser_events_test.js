const assert  = require('assert');
const brains  = require('./helpers/brains');
const Browser = require('../src');
const util    = require('util');


describe('Browser events', function() {
  const browser = new Browser();
  const events = {
    console:  [],
    log:      [],
    resource: []
  };
  const error = new Error('error');

  before(function() {
    return brains.ready();
  });

  describe('sending output to console', function() {
    before(function() {
      browser.silent = true;
    });

    before(function() {
      browser.on('console', function(level, message) {
        events.console.push({ level: level, message: message });
      });
      browser.console.log('Logging', 'message');
      browser.console.error('Some', error);
    });

    it('should receive console events with the log level', function() {
      assert.deepEqual(events.console[0].level, 'log');
      assert.deepEqual(events.console[1].level, 'error');
    });

    it('should receive console events with the message', function() {
      assert.deepEqual(events.console[0].message, 'Logging message');
      assert.deepEqual(events.console[1].message, 'Some ' + util.format(error));
    });

    after(function() {
      browser.silent = false;
    });
  });


  describe('logging a message', function() {
    it('should receive log events', function() {
      const error = new Error('error');
      // Zombie log
      browser.on('log', function(message) {
        events.log.push(message);
      });
      browser.log('Zombie', 'log');
      browser.log('Zombie', error);

      assert.equal(events.log[0], 'Zombie log');
      assert.equal(events.log[1], 'Zombie ' + util.format(error));
    });
  });


  describe('requesting a resource', function() {
    before(function() {
      brains.redirect('/browser-events/resource', '/browser-events/redirected');
      brains.static('/browser-events/redirected', '<html>Very well then</html>');

      browser.on('request', function(request) {
        events.resource.push([request.url]);
      });
      browser.on('redirect', function(request, response) {
        events.resource.push([request.url, response.url, response.status]);
      });
      browser.on('response', function(request, response) {
        events.resource.push([request.url, response.url, response.status]);
      });

      return browser.visit('/browser-events/resource');
    });

    it('should receive resource requests', function() {
      const [request] = events.resource[0];
      assert.equal(request, 'http://example.com/browser-events/resource');
    });

    it('should receive resource redirects', function() {
      const [request, response, status] = events.resource[1];
      assert.equal(request, 'http://example.com/browser-events/resource');
      assert.equal(response, 'http://example.com/browser-events/resource');
      assert.equal(status, 302);
    });

    it('should receive resource responses', function() {
      const [request, response, status] = events.resource[2];
      assert.equal(request, 'http://example.com/browser-events/redirected');
      assert.equal(response, 'http://example.com/browser-events/redirected');
      assert.equal(status, 200);
    });

  });

  describe('opening a window', function() {
    before(function() {
      browser.on('opened', function(window) {
        events.open = window;
      });
      browser.on('active', function(window) {
        events.active = window;
      });
      browser.open({ name: 'open-test' });
    });

    it('should receive opened event', function() {
      assert.equal(events.open.name, 'open-test');
    });

    it('should receive active event', function() {
      assert.equal(events.active.name, 'open-test');
    });
  });


  describe('closing a window', function() {
    before(function() {
      browser.on('closed', function(closedWindow) {
        events.close = closedWindow;
      });
      browser.on('inactive', function(inactiveWindow) {
        events.inactive = inactiveWindow;
      });
      const window = browser.open({ name: 'close-test' });
      window.close();
    });

    it('should receive closed event', function() {
      assert.equal(events.close.name, 'close-test');
    });

    it('should receive inactive event', function() {
      assert.equal(events.active.name, 'open-test');
    });
  });


  describe('loading a document', function() {
    before(function() {
      brains.static('/browser-events/document', '<html>Very well then</html>');

      browser.on('loading', function(document) {
        events.loading = [document.URL, document.readyState];
      });
      browser.on('loaded', function(document) {
        const html = document.documentElement.outerHTML;
        events.loaded = [document.URL, document.readyState, html];
      });

      return browser.visit('/browser-events/document');
    });

    it('should receive loading event', function() {
      const [url, readyState] = events.loading;
      assert.equal(url, 'http://example.com/browser-events/document');
      assert.equal(readyState, 'loading');
    });

    it('should receive loaded event', function() {
      const [url, readyState, html] = events.loaded;
      assert.equal(url, 'http://example.com/browser-events/document');
      assert.equal(readyState, 'complete');
      assert(/Very well then/.test(html));
    });
  });


  describe('firing an event', function() {
    before(async function() {
      await browser.load('<html><body>Hello</body></html>');

      browser.on('event', function(event, target) {
        if (event.type === 'click')
          events.click = { event, target };
      });

      browser.click('body');
      return browser.wait();
    });

    it('should receive DOM event', function() {
      assert.equal(events.click.event.type, 'click');
    });

    it('should receive DOM event target', function() {
      assert.equal(events.click.target, browser.document.body);
    });
  });


  describe('changing focus', function() {
    before(function() {
      brains.static('/browser-events/focus', `
        <html>
          <input id='input'>
          <script>document.getElementById('input').focus()</script>
        </html>`);

      browser.on('focus', function(element) {
        events.focus = element;
      });

      return browser.visit('/browser-events/focus');
    });

    it('should receive focus event', function() {
      const element = events.focus;
      assert.equal(element.id, 'input');
    });
  });


  describe('timeout fired', function() {
    before(function() {
      brains.static('/browser-events/timeout', `
        <html>
          <script>setTimeout(function() { }, 1);</script>
        </html>`);

      browser.on('setTimeout', function(fn, delay) {
        events.timeout = { fn, delay };
      });

      return browser.visit('/browser-events/timeout');
    });

    it('should receive timeout event with the function', function() {
      assert.equal(typeof events.timeout.fn, 'function');
    });

    it('should receive timeout event with the delay', function() {
      assert.equal(events.timeout.delay, 1);
    });
  });


  describe('interval fired', function() {
    before(function() {
      brains.static('/browser-events/interval', `
        <html>
          <script>setInterval(function() { }, 2);</script>
        </html>
      `);

      browser.on('setInterval', function(fn, interval) {
        events.interval = { fn, interval };
      });

      browser.visit('/browser-events/interval');
      return browser.wait({ duration: 100 });
    });

    it('should receive interval event with the function', function() {
      assert.equal(typeof events.interval.fn, 'function');
    });

    it('should receive interval event with the interval', function() {
      assert.equal(events.interval.interval, 2);
    });
  });


  describe('event loop empty', function() {
    before(function() {
      brains.static('/browser-events/idle', `
        <html>
          <script>setTimeout(function() { }, 1);</script>
        </html>
      `);

      browser.on('idle', function() {
        events.idle = true;
      });

      browser.visit('/browser-events/idle');
      events.idle = false;
      return browser.wait();
    });

    it('should receive idle event', function() {
      assert(events.idle);
    });
  });


  describe('evaluated', function() {
    before(function() {
      brains.static('/browser-events/evaluated', `
        <html>
          <script>window.foo = true</script>
        </html>
      `);

      browser.on('evaluated', function(code, result, filename) {
        events.evaluated = { code, result, filename };
      });

      return browser.visit('/browser-events/evaluated');
    });

    it('should receive evaluated event with the code', function() {
      assert.equal(events.evaluated.code, 'window.foo = true');
    });

    it('should receive evaluated event with the result', function() {
      assert.equal(events.evaluated.result, true);
    });

    it('should receive evaluated event with the filename', function() {
      assert.equal(events.evaluated.filename, 'http://example.com/browser-events/evaluated:script');
    });
  });


  describe('link', function() {
    before(async function() {
      brains.static('/browser-events/link', '<html><a href="follow"></a></html>');

      browser.on('link', function(url, target) {
        events.link = { url, target };
      });

      await browser.visit('/browser-events/link');
      // Incidentally test that we're able to ignore a 404
      await browser.click('a').catch(()=> null);
    });

    it('should receive link event with the URL', function() {
      assert.equal(events.link.url, 'http://example.com/browser-events/follow');
    });

    it('should receive link event with the target', function() {
      assert.equal(events.link.target, '_self');
    });
  });


  describe('submit', function() {
    before(async function() {
      brains.static('/browser-events/submit', '<html><form action="post"></form></html>');

      brains.static('/browser-events/post', '<html>Got it!</html>');

      browser.on('submit', function(url, target) {
        events.link = { url, target };
      });

      await browser.visit('/browser-events/submit');
      browser.query('form').submit();
      await browser.wait();
    });

    it('should receive submit event with the URL', function() {
      assert.equal(events.link.url, 'http://example.com/browser-events/post');
    });

    it('should receive submit event with the target', function() {
      assert.equal(events.link.target, '_self');
    });
  });


  after(function() {
    browser.destroy();
  });
});
