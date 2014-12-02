const assert      = require('assert');
const Browser     = require('../src/zombie');
const { brains }  = require('./helpers');
const WebSocket   = require('ws');


describe('WebSockets', function() {
  let browser;
  const prompts = [];

  before(function() {
    browser = Browser.create();
    return brains.ready();
  });

  before(function(done) {
    const server = new WebSocket.Server({ port: 3004 }, done);
    server.on('connection', function(client) {
      client.send('Hello');
    });
  });

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

    browser.visit('/websockets').done();
  });


  it('should be possible', function() {
    browser.assert.text('#ws-url', 'ws://example.com:3004');
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
