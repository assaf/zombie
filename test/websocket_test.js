const assert    = require('assert');
const Browser   = require('../src');
const brains    = require('./helpers/brains');
const WebSocket = require('ws');


describe('WebSockets', function() {
  let serverWS = null;

  before(function() {
    return brains.ready();
  });

  before(function(done) {
    const server = new WebSocket.Server({ port: 3004 }, done);
    server.on('connection', function(ws) {
      serverWS = ws;
      ws.send('Hello');
    });
  });

  describe('short session', function() {
    const browser = new Browser();
    const prompts = [];

    before(function() {
      brains.static('/websockets', `
        <html>
          <head>
            <script src="/scripts/jquery.js"></script>
          </head>
          <body>
            <span id="ws-url"></span>
          </body>
          <script>
            $(function() {
              var ws = new WebSocket('ws://example.com:3004');
              $('#ws-url').text(ws.url);
              ws.onopen = function() {
                alert('open');
              };
              ws.onmessage = function(message) {
                alert(message.data);
              };
              ws.onclose = function() {
                alert('close');
              };
              setTimeout(function() {
                ws.close();
              }, 100);
            });
          </script>
        </html>
      `);
    });

    before(function(done) {
      browser.on('alert', function(message) {
        prompts.push(message);
        if (message === 'close')
          done();
      });

      browser.visit('/websockets', ()=> null);
    });

    it('should be possible', function() {
      browser.assert.text('#ws-url', 'ws://example.com:3004/');
    });
    it('should raise open event after connecting', function() {
      assert.equal(prompts[0], 'open');
    });
    it('should raise message event for each message', function() {
      assert.equal(prompts[1], 'Hello');
    });
    it('should raise close event when closed', function() {
      assert.equal(prompts[2], 'close');
    });

    after(function() {
      browser.destroy();
    });
  });

  describe('connected indefinitely', function() {
    const browser = new Browser();

    before(function() {
      brains.static('/websockets2', `
        <html>
          <script>
            var ws = new WebSocket('ws://example.com:3004');
            ws.onmessage = function(message) {
              alert(message.data);

              // If message is received in a destroyed browser, this will throw an exception.
              setTimeout(function() {
                alert('timeout');
              }, 100);
            };
          </script>
        </html>
      `);
    });

    before(function(done) {
      browser.on('alert', function(message) {
        if (message === 'Hello')
          done();
      });

      browser.visit('/websockets2', ()=> null);
    });

    it('should close connection when leaving the page', function(done) {
      browser.visit('/');

      serverWS.send('after destroy');

      browser.wait(function() {
        assert.equal(serverWS.readyState, WebSocket.CLOSED);
        done();
      });
    });

    after(function() {
      browser.destroy();
    });
  });

  describe('binary data', function() {
    const browser = new Browser();

    before(function() {
      brains.static('/websockets-binary', `
        <html>
          <script>
            var ws = new WebSocket('ws://example.com:3004');
            ws.onmessage = function(message) {
              // If message is received in a destroyed browser, this will throw an exception.
              setTimeout(function() {
                alert('timeout');
              }, 100);

              // Allow 'buffer' to act as an alias for 'nodebuffer' because
              // versions of engine.io-client < 1.6.12 used 'buffer' for node clients
              ws.binaryType = 'buffer';
              alert(ws.binaryType);
            };
          </script>
        </html>
      `);
    });

    before(function(done) {
      const self = this;
      browser.on('alert', function(binaryType) {
        self.binaryType = binaryType;
        done();
      });

      browser.visit('/websockets-binary', ()=> null);
    });

    it('should convert buffer binary types to nodebuffer', function(done) {
      browser.visit('/');

      assert.equal(this.binaryType, 'nodebuffer');

      serverWS.send('after destroy');

      browser.wait(function() {
        assert.equal(serverWS.readyState, WebSocket.CLOSED);
        done();
      });
    });

    after(function() {
      browser.destroy();
    });
  });
});
