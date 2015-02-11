const assert      = require('assert');
const Browser     = require('../src/zombie');
const { brains }  = require('./helpers');


describe('IFrame', function() {
  const browser = Browser.create();
  let   iframe;

  before(function() {
    brains.static('/iframe', `
      <html>
        <head>
          <script src="/scripts/jquery.js"></script>
        </head>
        <body>
          <iframe name="ever"></iframe>
          <script>
            var frame = document.getElementsByTagName('iframe')[0];
            frame.src = '/iframe/static';
            frame.onload = function() {
              document.title = frame.contentDocument.title;
            }
          </script>
        </body>
      </html>`);

    brains.static('/iframe/static', `
      <html>
        <head>
          <title>What</title>
        </head>
        <body>
          Hello World
          <script>
            document.title = document.title + window.name;
          </script>
        </body>
      </html>`);

    return brains.ready();
  });


  before(async function() {
    await browser.visit('/iframe');
    iframe = browser.querySelector('iframe');
  });

  it('should fire onload event', function() {
    browser.assert.text('title', 'Whatever');
  });
  it('should load iframe document', function() {
    const iframeDocument = iframe.contentWindow.document;
    assert.equal('Whatever', iframeDocument.title);
    assert(/Hello World/.test(iframeDocument.body.innerHTML));
    assert.equal(iframeDocument.URL, 'http://example.com/iframe/static');
  });
  it('should set frame src attribute', function() {
    assert.equal(iframe.src, '/iframe/static');
  });
  it('should reference parent window from iframe', function() {
    assert.equal(iframe.contentWindow.parent, browser.window.parent);
  });
  it('should not alter the parent', function() {
    browser.assert.url('/iframe');
  });


  describe('javascript: protocol', function() {
    // Seen this in the wild, checking that it doesn't blow up
    it('should not blow up', async function() {
      iframe.src = 'javascript:false';
      await browser.wait();
    });
  });


  describe('postMessage', function() {
    before(function() {
      brains.static('/iframe/ping', `
        <html>
          <body>
            <iframe name="ping" src="/iframe/pong"></iframe>
            <script>
              // Give the frame a chance to load before sending message
              var iframe = document.getElementsByTagName('iframe')[0];
              iframe.addEventListener('load', function() {
                window.frames['ping'].postMessage('ping');
              });
              // Ready to receive response
              window.addEventListener('message', function(event) {
                document.title = event.data;
              });
            </script>
          </body>
        </html>`);
      brains.static('/iframe/pong', `
        <script>
          window.addEventListener('message', function(event) {
            if (event.data == 'ping')
              event.source.postMessage('pong ' + event.origin);
          });
        </script>`);
    });

    before(function() {
      return browser.visit('/iframe/ping');
    });

    it('should pass messages back and forth', function() {
      browser.assert.text('title', 'pong http://example.com');
    });
  });


  describe('referer', function() {
    before(function() {
      brains.get('/iframe/show-referer', function(req, res) {
        res.send(`<html><title>${req.headers['referer']}</title></html>`);
      });
      brains.static('/iframe/referer', `
        <html>
          <head></head>
          <body>
            <iframe name="child" src="/iframe/show-referer"></iframe>
          </body>
        </html>`);
    });

    before(function() {
      return browser.visit('/iframe/referer');
    });

    it('should be the parent\'s URL', function() {
      const document = browser.window.frames.child.document;
      const referrer = document.querySelector('title').textContent;
      assert.equal(referrer, 'http://example.com/iframe/referer');
    });

    after(function() {
      return browser.close();
    });
  });


  describe('link target', function() {
    before(function() {
      brains.static('/iframe/top', `
        <a target="_self" href="/target/_self">self</a>
        <a target="_blank" href="/target/_blank">blank</a>
        <iframe name="child" src="/iframe/child"></iframe>
        <a target="new-window" href="/target/new-window">new window</a>
        <a target="new-window" href="/target/existing-window">existing window</a>
      `);
      brains.static('/iframe/child', `
        <iframe name="child" src="/iframe/grand-child"></iframe>
      `);
      brains.static('/iframe/grand-child', `
        <a target="_parent" href="/target/_parent">blank</a>
        <a target="_top" href="/target/_top">blank</a>
      `);
      brains.static('/target/_self', '');
      brains.static('/target/_blank', '');
      brains.static('/target/_parent', '');
      brains.static('/target/_top', '');
      brains.static('/target/new-window', '');
      brains.static('/target/existing-window', '');
    });

    describe('_self', function() {
      before(async function() {
        await browser.visit('/iframe/top');
        await browser.clickLink('self');
      });

      it('should open link', function() {
        browser.assert.url({ pathname: '/target/_self' });
      });

      it('should open link in same window', function() {
        assert.equal(browser.tabs.index, 0);
      });

      after(function() {
        browser.close();
      });
    });

    describe('_blank', function() {
      before(async function() {
        await browser.visit('/iframe/top');
        assert.equal(browser.tabs.length, 1);
        await browser.clickLink('blank');
      });

      it('should open link', function() {
        browser.assert.url({ pathname: '/target/_blank' });
      });

      it('should open link in new window', function() {
        assert.equal(browser.tabs.length, 2);
        assert.equal(browser.tabs.index, 1);
      });

      after(function() {
        browser.close();
      });
    });

    describe('_top', function() {
      before(async function() {
        await browser.visit('/iframe/top');
        const twoDeep = browser.window.frames.child.frames.child.document;
        const link    = twoDeep.querySelector('a[target=_top]');

        const event = link.ownerDocument.createEvent('HTMLEvents');
        event.initEvent('click', true, true);
        link.dispatchEvent(event);
        await browser.wait();
      });

      it('should open link', function() {
        browser.assert.url({ pathname: '/target/_top' });
      });

      it('should open link in top window', function() {
        assert.equal(browser.tabs.index, 0);
      });

      after(function() {
        browser.close();
      });
    });

    describe('_parent', function() {
      before(async function() {
        await browser.visit('/iframe/top');
        const twoDeep = browser.window.frames.child.frames.child.document;
        const link    = twoDeep.querySelector('a[target=_parent]');

        const event = link.ownerDocument.createEvent('HTMLEvents');
        event.initEvent('click', true, true);
        link.dispatchEvent(event);
        await browser.wait();
      });

      it('should open link', function() {
        assert.equal(browser.window.frames.child.location.pathname, '/target/_parent');
      });

      it('should open link in child window', function() {
        browser.assert.url({ pathname: '/iframe/top' });
        assert.equal(browser.tabs.index, 0);
      });

      after(function() {
        browser.close();
      });
    });


    describe('window', function() {

      describe('new', function() {
        before(async function() {
          await browser.visit('/iframe/top');
          await browser.clickLink('new window');
        });

        it('should open link', function() {
          browser.assert.url({ pathname: '/target/new-window' });
        });

        it('should open link in new window', function() {
          assert.equal(browser.tabs.length, 2);
          assert.equal(browser.tabs.index, 1);
        });

        after(function() {
          browser.close();
        });
      });

      describe('existing', function() {
        before(async function() {
          await browser.visit('/iframe/top');
          await browser.clickLink('new window');
          browser.tabs.current = 0
          await browser.clickLink('existing window');
        });

        it('should open link', function() {
          browser.assert.url({ pathname: '/target/existing-window' });
        });
        it('should open link in existing window', function() {
          assert.equal(browser.tabs.length, 2);
        });
        it('should select existing window', function() {
          assert.equal(browser.tabs.index, 1);
        });

        after(function() {
          browser.close();
        });
      });
    });

  });


  after(function() {
    browser.destroy();
  });

});
