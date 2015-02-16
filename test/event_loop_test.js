const assert      = require('assert');
const Browser     = require('../src');
const { brains }  = require('./helpers');


describe('EventLoop', function() {
  const browser = new Browser();

  before(function() {
    brains.get('/eventloop/function', function(req, res) {
      res.send(`
        <html>
          <head><title></title></head>
        </html>
      `);
    });
    return brains.ready();
  });

  describe('setTimeout', function() {
    before(function() {
      brains.get('/eventloop/timeout', function(req, res) {
        res.send(`
          <html>
            <head><title>One</title></head>
            <body></body>
          </html>
        `);
      });
    });

    describe('not waiting', function() {
      before(async function() {
        await browser.visit('/eventloop/timeout');
        browser.window.setTimeout(function() {
          this.document.title += ' Two';
        }, 100);
        await setImmediate;
      });

      it('should not fire any timeout events', function() {
        browser.assert.text('title', 'One');
      });
    });

    describe('handle of first setTimeout', function() {
      // Use a new browser to make sure no other setTimeout call has
      // happened yet
      let handle;

      before(async function() {
        await browser.visit('/eventloop/timeout');
        handle = browser.window.setTimeout(Function, 100);
      });

      it('should be greater than 0', function() {
        assert.equal(handle, 1);
      });
    });

    describe('from within timeout', function() {
      before(async function() {
        await browser.visit('/eventloop/timeout');
        browser.window.setTimeout(function() {
          this.setTimeout(function() {
            this.document.title += ' Two';
            this.setTimeout(function() {
              this.document.title += ' Three';
            }, 100);
          }, 100);
        }, 100);
        await browser.wait();
      });

      it('should fire all timeout events', function() {
        browser.assert.text('title', 'One Two Three');
      });
    });


    describe('wait for all', function() {
      before(async function() {
        await browser.visit('/eventloop/timeout');
        browser.window.setTimeout(function() {
          this.document.title += ' Two';
        }, 100);
        browser.window.setTimeout(function() {
          this.document.title += ' Three';
        }, 200);
        await browser.wait(250);
      });

      it('should fire all timeout events', function() {
        browser.assert.text('title', 'One Two Three');
      });
    });


    describe('cancel timeout', function() {
      before(async function() {
        await browser.visit('/eventloop/timeout');
        browser.window.setTimeout(function() {
          this.document.title += ' Two';
        }, 100);
        const second = browser.window.setTimeout(function() {
          this.document.title += ' Three';
        }, 200);
        setTimeout(function() {
          browser.window.clearTimeout(second);
        }, 100);
        await browser.wait(300);
      });

      it('should fire only uncancelled timeout events', function() {
        browser.assert.text('title', 'One Two');
      });
      it('should not choke on invalid timers', function() {
        assert.doesNotThrow(function() {
          // clearTimeout should not choke when clearing an invalid timer
          // https://developer.mozilla.org/en/DOM/window.clearTimeout
          browser.window.clearTimeout(undefined);
        });
      });
    });


    describe('outside of wait', function() {
      before(async function() {
        await browser.visit('/eventloop/function');
        browser.window.setTimeout(function() { this.document.title += '1'; }, 100);
        browser.window.setTimeout(function() { this.document.title += '2'; }, 200);
        browser.window.setTimeout(function() { this.document.title += '3'; }, 300);
        await browser.wait(120); // wait long enough to fire no. 1
        await browser.wait(120); // wait long enough to fire no. 2
        // wait long enough to fire no. 3, but no events processed
        await new Promise((resolve)=> setTimeout(resolve, 200));
      });
      it('should not fire', function() {
        browser.assert.text('title', '12');
      });
    });


    describe('zero wait', function() {
      before(async function() {
        await browser.visit('/eventloop/timeout');
        browser.window.setTimeout(function() {
          this.document.title += ' Two';
        });
        await browser.wait();
      });

      it('should wait for event to fire', function() {
        browser.assert.text('title', 'One Two');
      });
    });
  });


  describe('setImmediate', function() {
    before(function() {
      brains.get('/eventloop/immediate', function(req, res) {
        res.send(`
          <html>
            <head><title></title></head>
            <body></body>
          </html>
        `);
      });
    });

    describe('with wait', function() {
      before(async function() {
        await browser.visit('/eventloop/immediate');
        browser.window.setImmediate(function() {
          this.document.title += '.';
        });
        await browser.wait();
      });

      it('should fire the immediate', function() {
        browser.assert.text('title', '.');
      });
    });

    describe('clearImmediate', function() {
      before(async function() {
        await browser.visit('/eventloop/immediate');
        const immediate = browser.window.setImmediate(function() {
          this.document.title += '.';
        });
        browser.window.clearImmediate(immediate);
        await browser.wait();
      });

      it('should not fire any immediates', function() {
        browser.assert.text('title', '');
      });
    });
  });


  describe('setInterval', function() {
    before(function() {
      brains.get('/eventloop/interval', function(req, res) {
        res.send(`
          <html>
            <head><title></title></head>
            <body></body>
          </html>
        `);
      });
    });

    describe('handle of first setInterval', function() {
      // Use a new browser to make sure no other setInterval call has
      // happened yet
      let handle;

      before(async function() {
        await browser.visit('/eventloop/interval');
        handle = browser.window.setInterval(Function, 100);
      });

      it('should be greater than 0', function() {
        assert.equal(handle, 1);
        browser.window.clearInterval(handle);
      });
    });

    describe('no wait', function() {
      before(async function() {
        await browser.visit('/eventloop/interval');
        browser.window.setInterval(function() {
          this.document.title += '.';
        }, 100);
        await setImmediate; 
      });

      it('should not fire any timeout events', function() {
        browser.assert.text('title', '');
      });
    });

    describe('wait once', function() {
      before(async function() {
        await browser.visit('/eventloop/interval');
        browser.window.setInterval(function() {
          this.document.title += '.';
        }, 100);
        await browser.wait(150);
      });

      it('should fire interval event once', function() {
        browser.assert.text('title', '.');
      });
    });

    describe('wait long enough', function() {
      before(async function() {
        await browser.visit('/eventloop/interval');
        browser.window.setInterval(function() {
          this.document.title += '.';
        }, 100);
        // Only wait for first 3 events
        await browser.wait(350);
      });

      it('should fire five interval event', function() {
        browser.assert.text('title', '...');
      });
    });

    describe('cancel interval', function() {
      before(async function() {
        await browser.visit('/eventloop/interval');
        const interval = browser.window.setInterval(function() {
          this.document.title += '.';
        }, 100);
        await browser.wait(250);
        browser.window.clearInterval(interval);
        await browser.wait(200);
      });

      it('should fire only uncancelled interval events', function() {
        browser.assert.text('title', '..');
      });
      it('should not throw an exception with invalid interval', function() {
        assert.doesNotThrow(function() {
          // clearInterval should not choke on invalid interval
          browser.window.clearInterval(undefined);
        });
      });
    });

    describe('outside wait', function() {
      before(async function() {
        await browser.visit('/eventloop/interval');
        browser.window.setInterval(function() {
          this.document.title += '.';
        }, 100);
        await browser.wait(120); // wait long enough to fire no. 1
        await browser.wait(120); // wait long enough to fire no. 2
        // wait long enough to fire no. 3, but no events processed
        await new Promise((resolve)=> setTimeout(resolve, 200));
      });

      it('should not fire', function() {
        browser.assert.text('title', '..');
      });
    });
  });


  describe('requestAnimationFrame', function() {
    before(function() {
      brains.static('/eventloop/requestAnimationFrame', `
        <html>
          <head><title></title></head>
          <body></body>
        </html>
      `);
    });

    describe('with wait', function() {
      before(async function() {
        await browser.visit('/eventloop/requestAnimationFrame');
        browser.window.requestAnimationFrame(function() {
          this.document.title += '.';
        });
        await browser.wait();
      });

      it('should fire the immediate', function() {
        browser.assert.text('title', '.');
      });
    });
  });


  describe('browser.wait completion', function() {
    function completed(window) {
      return window.document.title === '....';
    }

    before(async function() {
      await browser.visit('/eventloop/function');
      browser.window.setInterval(function() {
        this.document.title += '.';
      }, 100);
      await browser.wait({ function: completed });
    });

    it('should not wait longer than specified', function() {
      browser.assert.text('title', '....');
    });
  });


  // No callback -> event loop not runninga
  //
  // Test that when you call wait() with no callback, and don't attach anything
  // to the promise, event loop pauses.
  describe('wait', function() {
    before(function() {
      brains.static('/eventloop/wait', `
        <html>
          <title>
          </title>
        </html>
      `);
    });

    // This function is run in the context of the window (browser.evaluate), so
    // has access to the current document and event loop setTimeout.
    //
    // Asynchronously it will update the document title to say 'Bang'.
    function runAsynchronously() {
      const { document } = this;
      this.setTimeout(function() {
        document.title = 'Bang';
      }, 100);
    }

    describe('with Node callback', function() {
      before(function() {
        return browser.visit('/eventloop/wait');
      });

      before(function(done) {
        browser.evaluate(runAsynchronously);
        browser.wait(done);
      });

      it('should run asynchronous code', function() {
        browser.assert.text('title', 'Bang');
      });
    });

    describe('with promise callback', function() {
      before(function() {
        return browser.visit('/eventloop/wait');
      });

      before(function(done) {
        browser.evaluate(runAsynchronously);
        browser.wait().then(done, done);
      });

      it('should run asynchronous code', function() {
        browser.assert.text('title', 'Bang');
      });
    });

    describe('composed promise', function() {
      before(function() {
        return browser.visit('/eventloop/wait');
      });

      before(function() {
        browser.evaluate(runAsynchronously);
        const resolved = Promise.resolve();
        const composed = resolved.then(function() {
          return browser.wait();
        });
        return composed;
      });

      it('should run asynchronous code', function() {
        browser.assert.text('title', 'Bang');
      });
    });

  });


  describe('page load', function() {
    before(function() {
      brains.get('/eventloop/dcl', function(req, res) {
        res.send(`
          <html>
            <head><title></title></head>
            <script>
            window.documentDCL = 0;
            document.addEventListener('DOMContentLoaded', function() {
              ++window.documentDCL;
            });
            window.windowDCL = 0;
            window.addEventListener('DOMContentLoaded', function() {
              ++window.windowDCL;
            });
            </script>
            <div id="foo"></div>
          </html>
        `);
      });
      return browser.visit('/eventloop/dcl');
    });

    it('should file DOMContentLoaded event on document', function() {
      browser.assert.global('documentDCL', 1);
    });
    it('should file DOMContentLoaded event on window', function() {
      browser.assert.global('windowDCL', 1);
    });
  });

  describe('all resources loaded', function() {
    before(function() {
      brains.get('/eventloop/onload', function(req, res) {
        res.send(`
          <html>
            <head><title></title></head>
            <script src="/eventloop/onload.js"></script>
            <div id="foo"></div>
          </html>
        `);
      });
      brains.get('/eventloop/onload.js', function(req, res) {
        setTimeout(function() {
          res.send(`
            window.documentLoad = 0;
            document.addEventListener('load', function() {
              ++window.documentLoad;
            });
            window.windowLoad = 0;
            window.addEventListener('load', function() {
              ++window.windowLoad;
            });
          `);
        }, 100);
      });
      return browser.visit('/eventloop/onload');
    });

    it('should file load event on document', function() {
      browser.assert.global('documentLoad', 1);
    });
    it('should file load event on window', function() {
      browser.assert.global('windowLoad', 1);
    });

  });

  after(function() {
    browser.destroy();
  });
});

