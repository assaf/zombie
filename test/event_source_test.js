const assert      = require('assert');
const Browser     = require('../src/zombie');
const { brains }  = require('./helpers');


describe('EventSource', function() {
  let browser;

  before(function() {
    browser = Browser.create();
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
    assert.deepEqual(browser.evaluate('window.events'), ['first', 'second']);
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

  after(function() {
    browser.destroy();
  });
});

