const assert  = require('assert');
const brains  = require('./helpers/brains');
const Browser = require('../src');


describe('EventSource', function() {
  const browser = new Browser();

  before(function() {
    return brains.ready();
  });

  before(function() {
    brains.static('/streaming', `
      <html>
        <head>
          <script>
            var source    = new EventSource("/stream");
            window.events = [];
            source.addEventListener("test", function(event) {
              window.events.push(event.data);
            });
            /*
            setTimeout(function() {
              window.events.push("timeout");
            }, 100);
            */
          </script>
        </head>
        <body>
          <button>1</button>
        </body>
      </html>
    `);

    brains.get('/stream', function(req, res) {
      res.writeHead(200, {
        'Content-Type':   'text/event-stream; charset=utf-8',
        'Cache-Control':  'no-cache',
        'Connection':     'keep-alive'
      });
      // Send first event immediately
      setTimeout(function() {
        res.write('event: test\nid: 1\ndata: first\n\n');
      }, 10);
      // Send second event with some delay, still get to see this because of
      // client-side timeout
      setTimeout(function() {
        res.write('event: test\nid: 2\ndata: second\n\n');
      }, 50);
      // Send third event with too much delay, browser.wait() concluded
      setTimeout(function() {
        res.write('event: test\nid: 3\ndata: third\n\n');
        res.end();
      }, 200);
    });
  });


  describe('when present', function() {
    before(async function() {
      await browser.visit('/streaming');
      await browser.pressButton('1');
    });

    it('pressButton should not timeout', function() {
      assert(true);
    });
  });


  describe('wait', function() {
    before(async function() {
      await browser.visit('/streaming');
      await browser.wait();
    });

    it('should not wait for server event', function() {
      assert.deepEqual(browser.window.events, []);
    });
  });


  describe('waitForServer', function() {
    before(async function() {
      await browser.visit('/streaming');
      await browser.waitForServer();
    });

    it('should capture synchronous event', function() {
      assert.deepEqual(browser.window.events, ['first']);
    });

    it('should not wait longer than specified', function(done) {
      function gotTwoEvents(window) {
        return (window.events && window.events.length >= 2);
      }

      browser.waitForServer({ function: gotTwoEvents }, function() {
        assert.deepEqual(browser.window.events, ['first', 'second']);
        done();
      });
    });
  });


  after(function() {
    browser.destroy();
  });
});

