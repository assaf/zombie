const assert      = require('assert');
const Browser     = require('../src/zombie');
const { brains }  = require('./helpers');


describe('Scripts', function() {
  let browser;

  before(function() {
    browser = Browser.create();
    return brains.ready();
  });


  describe('basic', function() {
    before(function() {
      brains.static('/script/living', `
        <html>
          <head>
            <script src='/scripts/jquery.js'></script>
            <script src='/scripts/sammy.js'></script>
            <script src='/script/living/app.js'></script>
          </head>
          <body>
            <div id='main'>
              <a href='/script/dead'>Kill</a>
              <form action='#/dead' method='post'>
                <label>Email <input type='text' name='email'></label>
                <label>Password <input type='password' name='password'></label>
                <button>Sign Me Up</button>
              </form>
            </div>
            <div class='now'>Walking Aimlessly</div>
          </body>
        </html>`);

      brains.static('/script/living/app.js', `
        Sammy('#main', function(app) {
          app.get('#/', function(context) {
            document.title = 'The Living';
          });
          app.get('#/dead', function(context) {
            context.swap('The Living Dead');
          });
          app.post('#/dead', function(context) {
            document.title = 'Signed up';
          });
        });
        $(function() { Sammy('#main').run('#/') });
      `);
    });

    describe('run app', function() {
      before(function() {
        return browser.visit('/script/living');
      });

      it('should execute route', function() {
        browser.assert.text('title', 'The Living');
      });
      it('should change location', function() {
        browser.assert.url('/script/living#/');
      });


      describe('move around', function() {
        before(function() {
          browser.visit('/script/living#/dead');
          function hashChanged() {
            return browser.text('#main') == 'The Living Dead';
          }
          return browser.wait({ function: hashChanged });
        });

        it('should execute route', function() {
          browser.assert.text('#main', 'The Living Dead');
        });
        it('should change location', function() {
          browser.assert.url('/script/living#/dead');
        });
      });
    });


    describe('live events', function() {
      before(async function() {
        await browser.visit('/script/living/');
        browser.fill('Email', 'armbiter@zombies')
        browser.fill('Password', 'br41nz');
        await browser.pressButton('Sign Me Up');
      });

      it('should change location', function() {
        browser.assert.url('/script/living/#/');
      });
      it('should process event', function() {
        browser.assert.text('title', 'Signed up');
      });
    });


    describe('evaluate', function() {
      it('should evaluate in context and return value', async function() {
        await browser.visit('/script/living/');
        const title = browser.evaluate('document.title');
        assert.equal(title, 'The Living');
      });
    });
  });


  describe('evaluating', function() {

    describe('context', function() {
      before(function() {
        brains.static('/script/context', `
          <html>
            <script>var foo = 1</script>
            <script>window.foo = foo + 1</script>
            <script>document.title = this.foo</script>
            <script>
            setTimeout(function() {
              document.title = foo + window.foo
            });</script>
          </html>
        `);
        return browser.visit('/script/context');
      });

      it('should be shared by all scripts', function() {
        browser.assert.text('title', '4');
      });
    });


    describe('window', function() {
      before(function() {
        brains.static('/script/window', `
          <html>
            <script>document.title = [window == this,
                                      this == window.window,
                                      this == top,
                                      top == window.top,
                                      this == parent,
                                      top == parent].join(',')</script>
          </html>
        `);
        return browser.visit('/script/window');
      });

      it('should be the same as this, top and parent', function() {
        browser.assert.text('title', 'true,true,true,true,true,true');
      });
    });


    describe('global and function', function() {
      before(function() {
        brains.static('/script/global_and_fn', `
          <html>
            <script>
              var foo;
              (function() {
                if (!foo)
                  foo = 'foo';
              })();
              document.title = foo;
            </script>
          </html>
        `);
        return browser.visit('/script/global_and_fn');
      });

      it('should set global variable', function() {
        browser.assert.text('title', 'foo');
      });
    });

  });


  describe('order', function() {
    before(function() {
      brains.static('/script/order', `
        <html>
          <head>
            <title>Zero</title>
            <script src='/script/order.js'></script>
          </head>
          <body>
            <script>
              document.title = document.title + 'Two';
            </script>
          </body>
        </html>
      `);
      brains.static('/script/order.js', 'document.title = document.title + "One"');
      return browser.visit('/script/order');
    });

    it('should run scripts in order regardless of source', function() {
      browser.assert.text('title', 'ZeroOneTwo');
    });
  });


  describe('eval', function() {
    before(function() {
      brains.static('/script/eval', `
        <html>
          <script>
            var foo = 'One';
            (function() {
              var bar = 'Two'; // standard eval sees this\n
              var e = eval; // this 'eval' only sees global scope\n
              try {
                var baz = e('bar');
              } catch (ex) {
                var baz = 'Three';
              };
              // In spite of local variable, global scope eval finds global foo\n
              var foo = 'NotOne';
              var e_foo = e('foo');
              var qux = window.eval.call(window, 'foo');
              document.title = eval('e_foo + bar + baz + qux');
            })();
          </script>
        </html>
      `);
      return browser.visit('/script/eval');
    });

    it('should evaluate in global scope', function() {
      browser.assert.text('title', 'OneTwoThreeOne');
    });
  });


  describe('failing', function() {

    describe('incomplete', function() {
      let error;

      before(function() {
        brains.static('/script/incomplete', `
          <html>
            <script>1+</script>
          </html>
        `);
        return browser.visit('/script/incomplete').catch((err)=> error = err);
      });

      it('should pass error to callback', function() {
        assert.equal(error.message, 'Unexpected end of input');
      });

      it('should propagate error to window', function() {
        assert.equal(browser.error.message, 'Unexpected end of input');
      });
    });

    describe('error', function() {
      let error;

      before(function() {
        brains.static('/script/error', `
          <html>
            <script>(function(foo) { foo.bar })()</script>
          </html>
        `);
        return browser.visit('/script/error').catch((err)=> error = err);
      });

      it('should pass error to callback', function() {
        assert.equal(error.message, 'Cannot read property \'bar\' of undefined');
      });

      it('should propagate error to window', function() {
        assert.equal(browser.error.message, 'Cannot read property \'bar\' of undefined');
      });
    });
  });


  describe('loading', function() {

    describe('with entities', function() {
      before(function() {
        brains.static('/script/split', `
          <html>
            <script>foo = 1 < 2 ? 1 : 2; '&'; document.title = foo</script>
          </html>
        `);
        return browser.visit('/script/split');
      });

      it('should run full script', function() {
        browser.assert.text('title', '1');
      });
    });


    describe.skip('with CDATA', function() {
      before(function() {
        brains.static('/script/cdata', `
          <html>
            <script><![CDATA[ document.title = 2 ]]></script>
          </html>
        `);
        return browser.visit('/script/cdata');
      });

      it('should run full script', function() {
        assert.equal(browser.text('title'), '2');
      });
    });


    describe('using document.write', function() {
      before(function() {
        brains.static('/script/write', `
          <html>
            <body>
            <script>document.write(unescape('%3Cscript %3Edocument.title = document.title + ".write"%3C/script%3E'));</script>
            <script>
              document.title = document.title + 'document';
            </script>
            </body>
          </html>
        `);
        return browser.visit('/script/write');
      });

      it('should run script', function() {
        browser.assert.text('title', 'document.write');
      });
    });


    describe('using appendChild', function() {
      before(function() {
        brains.static('/script/append', `
          <html>
            <head>
              <script>
                var s = document.createElement('script'); s.type = 'text/javascript'; s.async = true;
                s.src = '/script/append.js';
                (document.getElementsByTagName('head')[0] || document.getElementsByTagName('body')[0]).appendChild(s);
              </script>
            </head>
            <body>
              <script>
                document.title = document.title + 'element.';
              </script>
            </body>
          </html>
        `);
        brains.static('/script/append.js', 'document.title = document.title + "appendChild"');
        return browser.visit('/script/append');
      });

      it('should run script', function() {
        browser.assert.text('title', 'element.appendChild');
      });
    });

  });


  describe('scripts disabled', function() {
    before(function() {
      brains.static('/script/no-scripts', `
        <html>
          <head>
            <title>Zero</title>
            <script src='/script/no-scripts.js'></script>
          </head>
          <body>
            <script>
            document.title = document.title + 'Two';</script>
          </body>
        </html>
      `);
      brains.static('/script/no-scripts.js', 'document.title = document.title + "One"');
      browser.features = 'no-scripts';
      return browser.visit('/script/order');
    });

    it('should not run scripts', function() {
      browser.assert.text('title', 'Zero');
    });

    after(function() {
      browser.features = 'scripts';
    });
  });


  describe('script attributes', function() {
    before(function() {
      brains.static('/script/inline', `
        <html>
          <head>
            <title></title>
            <script>var bar = null;</script>
          </head>
          <body>
          </body>
        </html>
      `);
      return browser.visit('/script/inline');
    });

    it('should have a valid src', function() {
      const nodes = browser.queryAll('script');
      assert.equal(nodes[0].src, '');
    });
  });


  describe('file:// uri scheme', function() {
    before(function() {
      return browser.visit(`file://${__dirname}/data/file_scheme.html`);
    });

    it('should run scripts with file url src', function() {
      browser.assert.text('title', 'file://');
    });
  });


  describe('file:// uri with encoded spaces', function() {
    before(function() {
      return browser.visit(`file://${__dirname}/data/dir%20with%20spaces/file_scheme%20with%20spaces.html`);
    });

    it('should run scripts with file url src containing encoded spaces', function() {
      browser.assert.text('title', 'file://');
    });
  });


  describe('javascript: URL', function() {

    describe('existing page', function() {
      before(async function() {
        await browser.visit('/script/living');
        await browser.visit('javascript:window.message = "hi"');
      });

      it('should evaluate script in context of window', function() {
        browser.assert.evaluate('message', 'hi');
      });
    });

    describe('blank page', function() {
      before(function() {
        browser.tabs.close();
        return browser.visit('javascript:window.message = "hi"');
      });

      it('should evaluate script in context of window', function() {
        browser.assert.evaluate('message', 'hi');
      });
    });

  });


  describe('new Image', function() {
    it('should construct an img tag', function() {
      browser.assert.evaluate('new Image().tagName', 'IMG');
    });
    it('should construct an img tag with width and height', function() {
      browser.assert.evaluate('new Image(1, 1).height', 1);
    });
  });


  describe('Event', function() {
    it('should be available in global context', function() {
      browser.assert.evaluate('Event');
    });
  });


  describe('on- event handler (string)', function() {
    before(async function() {
      brains.static('/script/on-event/string', `
        <form onsubmit='document.title = event.eventType; return false'>
          <button>Submit</button>
        </form>
      `);
      await browser.visit('/script/on-event/string');
      await browser.pressButton('Submit');
    });

    it('should prevent default handling by returning false', function() {
      browser.assert.url('/script/on-event/string');
    });

    it('should have access to window.event', function() {
      browser.assert.text('title', 'HTMLEvents');
    });
  });


  describe('on- event handler (function)', function() {
    before(async function() {
      brains.static('/script/on-event/function', `
        <form>
          <button>Submit</button>
        </form>
        <script>
          document.getElementsByTagName('form')[0].onsubmit = function(event) {
            document.title = event.eventType;
            event.preventDefault();
          }
        </script>
      `);
      await browser.visit('/script/on-event/function');
      await browser.pressButton('Submit');
    });

    it('should prevent default handling by returning false', function() {
      browser.assert.url('/script/on-event/function');
    });

    it('should have access to window.event', function() {
      browser.assert.text('title', 'HTMLEvents');
    });
  });


  describe('JSON parsing', function() {
    it('should respect prototypes', function() {
      browser.assert.evaluate(`
        Array.prototype.method = function() {};
        JSON.parse('[0, 1]').method;
      `);
    });
  });


  after(function() {
    browser.destroy();
  });
});

