const assert      = require('assert');
const Browser     = require('../src');
const { brains }  = require('./helpers');


describe('Browser assert', function() {
  const browser = new Browser();

  before(function() {
    return brains.ready();
  });


  describe('link', function() {
    before(function() {
      brains.static('/assert/link', `
        <!DOCTYPE html>
        <html lang=en>
          <head><title>test</title></head>
          <body>
            <div>
              <p id="p-id">
                <a href="/assert/link/link-to-some-id-12345" id="link-id">Link Text</a>
              </p>
            </div>
          </body>
        </html>
      `);
      brains.static('/assert/link/link-to-some-id-12345', `
        <html>
          <body>
          </body>
        </html>
      `);
    });


    before(function() {
      return browser.visit('/assert/link');
    });

    it('should find the link using a wide selector', function() {
      browser.assert.link('a', 'Link Text', '/assert/link/link-to-some-id-12345');
    });

    it('should find the link using a specific selector', function() {
      browser.assert.link('div p a', 'Link Text', '/assert/link/link-to-some-id-12345');
    });

    it('should find the link using an id selector', function() {
      browser.assert.link('#link-id', 'Link Text', '/assert/link/link-to-some-id-12345');
    });

    it('should find the link when given a RegExp for the url', function() {
      browser.assert.link('#link-id', 'Link Text', /\/assert\/link\/link\-to\-some\-id\-\d*$/);
    });
  });


  after(function() {
    browser.destroy();
  });
});

