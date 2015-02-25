const Browser = require('../src');
const brains  = require('./helpers/brains');


describe('require.js', function() {
  const browser = new Browser();

  before(function() {
    brains.static('/requirejs', `
      <html>
        <head>
          <script>
            var require = {
              paths: {
                main:   '/requirejs/index',
                jquery: '/scripts/jquery'
              }
            };
          </script>
          <script data-main="/requirejs/index" src="/scripts/require.js"></script>
        </head>
        <body>
          Hi there.
        </body>
      </html>`);
    brains.static('/requirejs/index.js', `
      define(['dependency'], function(dependency) {
        dependency();
      });
    `);
    brains.static('/requirejs/dependency.js', `
      define(['jquery'], function($) {
        return function() {
          document.title = 'Dependency loaded';
          $('body').text('Hello');
        }
      })
    `);

    return brains.ready();
  });

  before(function() {
    return browser.visit('/requirejs');
  });

  it('should load dependencies', function() {
    browser.assert.text('title', 'Dependency loaded');
  });

  it('should run main module', function() {
    browser.assert.text('body', 'Hello');
  });

  after(function() {
    browser.destroy();
  });
});

