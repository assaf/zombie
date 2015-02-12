const assert      = require('assert');
const Browser     = require('../src');
const { brains }  = require('./helpers');


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
            var source = new EventSource("/stream");
            window.events = [];
            source.addEventListener("test", function(event) {
              if (window.events.length > 0) setTimeout(function() {
                  window.events.push("third")
              }, 50)
              window.events.push(event.data)
            });
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
      res.write('event: test\nid: 1\ndata: first\n\n');
      setTimeout(function() {
        res.write('event: test\nid: 2\ndata: second\n\n');
        res.end();
      }, 100);
    });
  });

  before(function(done) {
    browser.visit('/streaming').done(done,done);
  });

  it('should stream to browser', async function() {
    await browser.waitForServer()
    assert.deepEqual(browser.evaluate('window.events'), ['first', 'second','third']);
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


  describe('browser.waitForServer', function() {
    before(async function() {
      await browser.visit('/streaming');
      await browser.waitForServer();
    });

    it('should capture synchronous event', function() {
      assert.deepEqual(browser.evaluate('window.events'), ['first']);
    });

    it('should not wait longer than specified', function(done) {
      function gotTwoEvents(window) {
        return (window.events && window.events.length === 2);
      }

      browser.waitForServer({ function: gotTwoEvents }, function() {
        assert.deepEqual(browser.evaluate('window.events'), ['first', 'second']);
        done();
      });
    });
  });

  after(function() {
    browser.destroy();
  });
});

