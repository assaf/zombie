const assert  = require('assert');
const brains  = require('./helpers/brains');
const Browser = require('../src');


const JQUERY_VERSIONS = ['1.4.4', '1.5.1', '1.6.3', '1.7.1', '1.8.0', '1.9.1', '2.0.3'];


describe('Compatibility with jQuery', function() {
  const browser = new Browser();

  before(function() {
    return brains.ready();
  });

  for (let version of JQUERY_VERSIONS) {
  
    describe(version, function() {
      before(function() {
        brains.static(`/compat/jquery-${version}`, `
          <html>
            <head>
              <title>jQuery ${version}</title>
              <script src="/scripts/jquery-${version}.js"></script>
            </head>
            <body>
              <form action="/zombie/dead-end">
                <select>
                  <option>None</option>
                  <option value="1">One</option>
                </select>

                <span id="option"></span>

                <a href="#post">Post</a>

                <div id="response"></div>

                <input id="edit-subject" value="Subject">
                <textarea id="edit-note">Note</textarea>

                <button class="some-class">Click Me</button>
              </form>

              <script>
                $(function() {

                  $('select').bind('change', function() {
                    $('#option').text(this.value);
                  });

                  $('a[href="#post"]').click(function() {
                    $.post('/compat/echo/jquery-${version}', {'foo': 'bar'}, function(response) {
                      $('#response').text(response);
                    });

                    return false;
                  });
                });
              </script>
            </body>
          </html>`);

        brains.static('/zombie/dead-end', '');
        brains.post(`/compat/echo/jquery-${version}`, function(req, res) {
          const body = Object.keys(req.body)
            .map(key => [key, req.body[key]].join('=') )
            .join('\n');
          res.send(body);
        });
      });

      before(function() {
        return browser.visit(`/compat/jquery-${version}`);
      });


      describe('selecting an option in a select element', function() {
        before(function() {
          browser.select('select', '1');
        });

        it('should fire the change event', function() {
          browser.assert.text('#option', '1');
        });
      });


      describe('jQuery.post', function() {
        before(function() {
          return browser.clickLink('Post');
        });

        it('should perform an AJAX POST request', function() {
          browser.assert.text('#response', /foo=bar/);
        });
      });


      describe('jQuery.globalEval', function() {
        before(function() {
          browser.evaluate(`
            (function () {
              $.globalEval('var globalEvalWorks = true;');
            })();
          `);
        });

        it('should work as expected', function() {
          browser.assert.global('globalEvalWorks', true);
        });
      });


      describe('setting val to empty', function() {
        it('should set to empty', function() {
          browser.assert.input('#edit-subject', 'Subject');
          browser.window.$('input#edit-subject').val('');
          browser.assert.input('#edit-subject', '');

          browser.assert.input('#edit-note', 'Note');
          browser.window.$('textarea#edit-note').val('');
          browser.assert.input('#edit-note', '');
        });
      });


      // See issue 235 https://github.com/assaf/zombie/issues/235
      if (version > '1.6') {

        describe('undefined attribute', function() {
          it('should return undefined', function() {
            assert.equal(browser.window.$('#response').attr('class'), undefined);
          });
        });

        describe('closest with attribute selector', function() {
          it('should find element', function() {
            browser.window.$('#response').html('<div class="ok">');
            assert.equal(browser.window.$('#response .ok').closest('[id]').attr('id'), 'response');
          });
        });

      }


      if (version > '1.9') {

        describe('live events', function() {
          before(function(done) {
            browser.visit(`/compat/jquery-${version}`, function() {
              browser.window.$(browser.document).on('click', '.skip-me', function() {
                done(new Error('unexpected event capture'));
              });
              browser.window.$(browser.document).on('click', '.some-class', function() {
                done();
              });
              browser.pressButton('Click Me');
            });
          });

          it('should catch live event handler', function() {
            assert(true);
          });
        });

      } else if (version > '1.7') {

        describe('live events', function() {
          before(function(done) {
            browser.visit(`/compat/jquery-${version}`, function() {
              browser.window.$(browser.document).live('click', '.some-class', function() {
                done();
              });
              browser.pressButton('Click Me');
            });
          });

          it('should catch live event handler', function() {
            assert(true);
          });
        });

      }

      if (version > '1.7') {

        describe('preventDefault', function() {
        });
          before(function(done) {
            browser.visit(`/compat/jquery-${version}`, function() {
              browser.window.$(browser.document).on('click', '.some-class', function(event) {
                event.preventDefault();
              });
              browser.pressButton('Click Me', done);
            });
          });

          it('should respect it', function() {
            assert(browser.location.pathname !== '/zombie/dead-end');
          });
      }

    });
  }

  after(function() {
    browser.destroy();
  });
});

