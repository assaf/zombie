const assert      = require('assert');
const Browser     = require('../src/zombie');
const { brains }  = require('./helpers');


describe("EventLoop", function() {
  let browser;

  before(function() {
    browser = Browser.create();
    brains.get('/eventloop/function', function(req, res) {
      res.send(`
        <html>
          <head><title></title></head>
        </html>
      `);
    });
    return brains.ready();
  });

  describe("setTimeout", function() {
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

    describe("no wait", function() {
      before(function*() {
        yield browser.visit('/eventloop/timeout');
        browser.window.setTimeout(function() {
          this.document.title += " Two";
        }, 100);
        yield setImmediate;
      });

      it("should not fire any timeout events", function() {
        browser.assert.text('title', "One");
      });
    });

    describe("timerHandle of first setTimeout", function() {
      // Use a new browser to make sure no other setTimeout call has
      // happened yet
      let localBrowser = Browser.create();
      let timerHandle;

      before(function*() {
        yield localBrowser.visit('/eventloop/timeout');
        timerHandle = localBrowser.window.setTimeout(function() {
          this.document.title += " Two";
        }, 100);
      });

      it("should be greater than 0", function() {
        assert.equal(timerHandle, 1);
      });
    });

    describe("from timeout", function() {
      before(function*() {
        yield browser.visit('/eventloop/timeout');
        browser.window.setTimeout(function() {
          this.setTimeout(function() {
            this.document.title += " Two";
            this.setTimeout(function() {
              this.document.title += " Three";
            }, 100);
          }, 100);
        }, 100);
        yield browser.wait();
      });

      it("should fire all timeout events", function() {
        browser.assert.text('title', "One Two Three");
      });
    });


    describe("wait for all", function() {
      before(function*() {
        yield browser.visit('/eventloop/timeout');
        browser.window.setTimeout(function() {
          this.document.title += " Two";
        }, 100);
        browser.window.setTimeout(function() {
          this.document.title += " Three";
        }, 200);
        yield browser.wait(250);
      });

      it("should fire all timeout events", function() {
        browser.assert.text('title', "One Two Three");
      });
    });


    describe("cancel timeout", function() {
      before(function*() {
        yield browser.visit('/eventloop/timeout');
        browser.window.setTimeout(function() {
          this.document.title += " Two";
        }, 100);
        let second = browser.window.setTimeout(function() {
          this.document.title += " Three";
        }, 200);
        setTimeout(function() {
          browser.window.clearTimeout(second);
        }, 100);
        yield browser.wait(300);
      });

      it("should fire only uncancelled timeout events", function() {
        browser.assert.text('title', "One Two");
      });
      it("should not choke on invalid timers", function() {
        assert.doesNotThrow(function() {
          // clearTimeout should not choke when clearing an invalid timer
          // https://developer.mozilla.org/en/DOM/window.clearTimeout
          browser.window.clearTimeout(undefined);
        });
      });
    });

    describe("outside wait", function() {
      before(function*() {
        yield browser.visit('/eventloop/function');
        browser.window.setTimeout(function() { this.document.title += '1'; }, 100);
        browser.window.setTimeout(function() { this.document.title += '2'; }, 200);
        browser.window.setTimeout(function() { this.document.title += '3'; }, 300);
        yield browser.wait(120); // wait long enough to fire no. 1
        yield browser.wait(120); // wait long enough to fire no. 2
        // wait long enough to fire no. 3, but no events processed
        yield (resume)=> setTimeout(resume, 200);
      });
      it("should not fire", function() {
        browser.assert.text('title', "12");
      });
    });


    describe("zero wait", function() {
      before(function*() {
        yield browser.visit('/eventloop/timeout');
        browser.window.setTimeout(function() {
          this.document.title += " Two";
        });
        yield browser.wait();
      });

      it("should wait for event to fire", function() {
        browser.assert.text('title', "One Two");
      });
    });
  });


  describe("setImmediate", function() {
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

    describe("with wait", function() {
      before(function*() {
        yield browser.visit('/eventloop/immediate');
        browser.window.setImmediate(function() {
          this.document.title += ".";
        });
        yield browser.wait();
      });

      it("should not fire the immediate", function() {
        browser.assert.text('title', ".");
      });
    });

    describe("clearImmediate", function() {
      before(function*() {
        yield browser.visit('/eventloop/immediate');
        let immediate = browser.window.setImmediate(function() {
          this.document.title += ".";
        });
        browser.window.clearImmediate(immediate);
        yield browser.wait();
      });

      it("should not fire any immediates", function() {
        browser.assert.text('title', "");
      });
    });
  });


  describe("setInterval", function() {
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

    describe("timerHandle of first setInterval", function() {
      // Use a new browser to make sure no other setInterval call has
      // happened yet
      let localBrowser = Browser.create();
      let timerHandle;

      before(function*() {
        yield localBrowser.visit('/eventloop/interval');
        timerHandle = localBrowser.window.setInterval(function() {
          this.document.title += " Two";
        }, 100);
      });

      it("should be greater than 0", function() {
        assert.equal(timerHandle, 1);
        localBrowser.window.clearInterval(timerHandle);
      });
    });

    describe("no wait", function() {
      before(function*() {
        yield browser.visit('/eventloop/interval');
        browser.window.setInterval(function() {
          this.document.title += ".";
        }, 100);
        yield setImmediate; 
      });

      it("should not fire any timeout events", function() {
        browser.assert.text('title', "");
      });
    });

    describe("wait once", function() {
      before(function*() {
        yield browser.visit('/eventloop/interval');
        browser.window.setInterval(function() {
          this.document.title += ".";
        }, 100);
        yield browser.wait(150);
      });

      it("should fire interval event once", function() {
        browser.assert.text('title', ".");
      });
    });

    describe("wait long enough", function() {
      before(function*() {
        yield browser.visit('/eventloop/interval');
        browser.window.setInterval(function() {
          this.document.title += ".";
        }, 100);
        // Only wait for first 3 events
        yield browser.wait(350);
      });

      it("should fire five interval event", function() {
        browser.assert.text('title', "...");
      });
    });

    describe("cancel interval", function() {
      before(function*() {
        yield browser.visit('/eventloop/interval');
        let interval = browser.window.setInterval(function() {
          this.document.title += ".";
        }, 100);
        yield browser.wait(250);
        browser.window.clearInterval(interval);
        yield browser.wait(200);
      });

      it("should fire only uncancelled interval events", function() {
        browser.assert.text('title', "..");
      });
      it("should not throw an exception with invalid interval", function() {
        assert.doesNotThrow(function() {
          // clearInterval should not choke on invalid interval
          browser.window.clearInterval(undefined);
        });
      });
    });

    describe("outside wait", function() {
      before(function*() {
        yield browser.visit('/eventloop/interval');
        browser.window.setInterval(function() {
          this.document.title += ".";
        }, 100);
        yield browser.wait(120); // wait long enough to fire no. 1
        yield browser.wait(120); // wait long enough to fire no. 2
        // wait long enough to fire no. 3, but no events processed
        yield (resume)=> setTimeout(resume, 200);
      });

      it("should not fire", function() {
        browser.assert.text('title', "..");
      });
    });
  });

  describe("browser.wait completion", function() {
    function completed(window) {
      return window.document.title === "....";
    }

    before(function*() {
      yield browser.visit('/eventloop/function');
      browser.window.setInterval(function() {
        this.document.title += ".";
      }, 100);
      yield browser.wait({ function: completed });
    });

    it("should not wait longer than specified", function() {
      browser.assert.text('title', "....");
    });
  });


  describe("page load", function() {
    before(function() {
      brains.get('/eventloop/dcl', function(req, res) {
        res.send(`
          <html>
            <head><title></title></head>
            <script>
            window.documentDCL = 0;
            document.addEventListener("DOMContentLoaded", function() {
              ++window.documentDCL;
            });
            window.windowDCL = 0;
            window.addEventListener("DOMContentLoaded", function() {
              ++window.windowDCL;
            });
            </script>
            <div id="foo"></div>
          </html>
        `);
      });
      return browser.visit('/eventloop/dcl');
    });

    it("should file DOMContentLoaded event on document", function() {
      browser.assert.global('documentDCL', 1);
    });
    it("should file DOMContentLoaded event on window", function() {
      browser.assert.global('windowDCL', 1);
    });
  });

  describe("all resources loaded", function() {
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
            document.addEventListener("load", function() {
              ++window.documentLoad;
            });
            window.windowLoad = 0;
            window.addEventListener("load", function() {
              ++window.windowLoad;
            });
          `);
        }, 100);
      });
      return browser.visit('/eventloop/onload');
    });

    it("should file load event on document", function() {
      browser.assert.global('documentLoad', 1);
    });
    it("should file load event on window", function() {
      browser.assert.global('windowLoad', 1);
    });

  });

  after(function() {
    browser.destroy();
  });
});

