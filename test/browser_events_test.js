const assert      = require('assert');
const Browser     = require('../src/zombie');
const { brains }  = require('./helpers');
const HTML        = require('jsdom').dom.level3.html;


describe("Browser events", function() {
  let browser;
  let events = {
    console:  [],
    log:      [],
    resource: []
  };

  before(function*() {
    browser = Browser.create();
    yield brains.ready();
  });

  describe("sending output to console", function() {
    before(function() {
      browser.on('console', function(level, message) {
        events.console.push({ level: level, message: message });
      });
      browser.console.log("Logging", "message");
      browser.console.error("Some", new Error("error"));
    });

    it("should receive console events with the log level", function() {
      assert.deepEqual(events.console[0].level, 'log');
      assert.deepEqual(events.console[1].level, 'error');
    });

    it("should receive console events with the message", function() {
      assert.deepEqual(events.console[0].message, "Logging message");
      assert.deepEqual(events.console[1].message, "Some [Error: error]");
    });
  });


  describe("logging a message", function() {
    it("should receive log events", function*() {
      // Zombie log
      browser.on('log', function(message) {
        events.log.push(message);
      });
      browser.log("Zombie", "log")
      browser.log("Zombie", new Error("error"));

      assert.equal(events.log[0], "Zombie log");
      assert.equal(events.log[1], "Zombie [Error: error]");
    });
  });


  describe("requesting a resource", function() {
    before(function*() {
      brains.get('/browser-events/resource', function(req, res) {
        res.redirect('/browser-events/redirected');
      });
      brains.get('/browser-events/redirected', function(req, res) {
        res.send("<html>Very well then</html>");
      });

      browser.on('request', function(request) {
        events.resource.push([request]);
      });
      browser.on('redirect', function(request, response) {
        events.resource.push([request, response]);
      });
      browser.on('response', function(request, response) {
        events.resource.push([request, response]);
      });

      yield browser.visit('/browser-events/resource');
    });

    it("should receive resource requests", function() {
      let [request] = events.resource[0];
      assert.equal(request.url, 'http://localhost:3003/browser-events/resource');
    });

    it("should receive resource redirects", function() {
      let [request, response] = events.resource[1];
      assert.equal(request.url, 'http://localhost:3003/browser-events/resource');
      assert.equal(response.statusCode, 302);
      assert.equal(response.url, 'http://localhost:3003/browser-events/redirected');
    });

    it("should receive resource responses", function() {
      let [request, response] = events.resource[2];
      assert.equal(request.url, 'http://localhost:3003/browser-events/resource');
      assert.equal(response.statusCode, 200);
      assert.equal(response.redirects, 1);
    });

  });

  describe("opening a window", function() {
    before(function() {
      browser.on('opened', function(window) {
        events.open = window;
      });
      browser.on('active', function(window) {
        events.active = window;
      });
      browser.open({ name: 'open-test' });
    });

    it("should receive opened event", function() {
      assert.equal(events.open.name, 'open-test');
    });

    it("should receive active event", function() {
      assert.equal(events.active.name, 'open-test');
    });
  });


  describe("closing a window", function() {
    before(function() {
      let window;
      browser.on('closed', function(window) {
        events.close = window;
      });
      browser.on('inactive', function(window) {
        events.inactive = window;
      });
      window = browser.open({ name: 'close-test' });
      window.close();
    });

    it("should receive closed event", function() {
      assert.equal(events.close.name, 'close-test');
    });

    it("should receive inactive event", function() {
      assert.equal(events.active.name, 'open-test');
    });
  });


  describe("loading a document", function() {
    before(function*() {
      brains.get('/browser-events/document', function(req, res) {
        res.send("<html>Very well then</html>");
      });

      browser.on('loading', function(document) {
        events.loading = [document.URL, document.readyState, document.outerHTML];
      });
      browser.on('loaded', function(document) {
        events.loaded = [document.URL, document.readyState, document.outerHTML];
      });

      yield browser.visit('/browser-events/document');
    });

    it("should receive loading event", function() {
      let [url, readyState, html] = events.loading;
      assert.equal(url, 'http://localhost:3003/browser-events/document');
      assert.equal(readyState, 'loading');
      assert.equal(html, "");
    });

    it("should receive loaded event", function() {
      let [url, readyState, html] = events.loaded;
      assert.equal(url, 'http://localhost:3003/browser-events/document');
      assert.equal(readyState, 'complete');
      assert(/Very well then/.test(html));
    });
  });


  describe("firing an event", function() {
    before(function*() {
      browser.load("<html><body>Hello</body></html>");

      browser.on('event', function(event, target) {
        if (event.type == 'click')
          events.click = { event, target };
      });

      browser.click('body');
      yield browser.wait();
    });

    it("should receive DOM event", function() {
      assert.equal(events.click.event.type, 'click');
    });

    it("should receive DOM event target", function() {
      assert.equal(events.click.target, browser.document.body);
    });
  });


  describe("changing focus", function() {
    before(function*() {
      brains.get('/browser-events/focus', function(req, res) {
        res.send("\
        <html>\
          <input id='input'>\
          <script>document.getElementById('input').focus()</script>\
        </html>\
        ");
      });

      browser.on('focus', function(element) {
        events.focus = element;
      });

      yield browser.visit('/browser-events/focus');
    });

    it("should receive focus event", function() {
      let element = events.focus;
      assert.equal(element.id, 'input');
    });
  });


  describe("timeout fired", function() {
    before(function*() {
      brains.get('/browser-events/timeout', function(req, res) {
        res.send("\
        <html>\
          <script>setTimeout(function() { }, 1);</script>\
        </html>\
        ");
      });

      browser.on('timeout', function(fn, delay) {
        events.timeout = { fn, delay };
      });

      yield browser.visit('/browser-events/timeout');
    });

    it("should receive timeout event with the function", function() {
      assert.equal(typeof(events.timeout.fn), 'function');
    });

    it("should receive timeout event with the delay", function() {
      assert.equal(events.timeout.delay, 1);
    });
  });


  describe("interval fired", function() {
    before(function*() {
      brains.get('/browser-events/interval', function(req, res) {
        res.send("\
        <html>\
          <script>setInterval(function() { }, 2);</script>\
        </html>\
        ");
      });

      browser.on('interval', function(fn, interval) {
        events.interval = { fn, interval };
      });

      browser.visit('/browser-events/interval')
      yield browser.wait({ duration: 100 });
    });

    it("should receive interval event with the function", function() {
      assert.equal(typeof(events.interval.fn), 'function');
    });

    it("should receive interval event with the interval", function() {
      assert.equal(events.interval.interval, 2);
    });
  });


  describe("event loop empty", function() {
    before(function*() {
      brains.get('/browser-events/done', function(req, res) {
        res.send("\
        <html>\
          <script>setTimeout(function() { }, 1);</script>\
        </html>\
        ");
      });

      browser.on('done', function() {
        events.done = true;
      });

      browser.visit('/browser-events/done');
      events.done = false;
      yield browser.wait();
    });

    it("should receive done event", function() {
      assert(events.done);
    });
  });


  describe("evaluated", function() {
    before(function*() {
      brains.get('/browser-events/evaluated', function(req, res) {
        res.send("\
        <html>\
          <script>window.foo = true</script>\
        </html>\
        ");
      });

      browser.on('evaluated', function(code, result, filename) {
        events.evaluated = { code, result, filename };
      });

      yield browser.visit('/browser-events/evaluated');
    });

    it("should receive evaluated event with the code", function() {
      assert.equal(events.evaluated.code, "window.foo = true");
    });

    it("should receive evaluated event with the result", function() {
      assert.equal(events.evaluated.result, true);
    });

    it("should receive evaluated event with the filename", function() {
      assert.equal(events.evaluated.filename, 'http://localhost:3003/browser-events/evaluated:script');
    });
  });


  describe("link", function() {
    before(function*() {
      brains.get('/browser-events/link', function(req, res) {
        res.send("<html><a href='follow'></a></html>");
      });

      browser.on('link', function(url, target) {
        events.link = { url, target };
      });

      yield browser.visit('/browser-events/link');
      browser.click('a');
    });

    it("should receive link event with the URL", function() {
      assert.equal(events.link.url, 'http://localhost:3003/browser-events/follow');
    });

    it("should receive link event with the target", function() {
      assert.equal(events.link.target, '_self');
    });
  });


  describe("submit", function() {
    before(function*() {
      brains.get('/browser-events/submit', function(req, res) {
        res.send("<html><form action='post'></form></html>");
      });

      brains.get('/browser-events/post', function(req, res) {
        res.send("<html>Got it!</html>");
      });

      browser.on('submit', function(url, target) {
        events.link = { url, target };
      });

      yield browser.visit('/browser-events/submit');
      browser.query('form').submit();
      yield browser.wait();
    });

    it("should receive submit event with the URL", function() {
      assert.equal(events.link.url, 'http://localhost:3003/browser-events/post');
    });

    it("should receive submit event with the target", function() {
      assert.equal(events.link.target, '_self');
    });
  });


  after(function() {
    browser.destroy();
  });
});
