const assert      = require('assert');
const brains      = require('./helpers/brains');
const Browser     = require('../src');
const thirdParty  = require('./helpers/thirdparty');


describe.only('Data Attribute Test', function() {
  const browser = new Browser();

  before(function() {
    return brains.ready();
  });
  
  describe('document', function() {
    before(function() {
      brains.static('/data', `
        <!DOCTYPE html>
        <html>
          <head>
            <meta charset="utf-8">
            <title></title>
          </head>
          <body>
            <section data-test-attr="fake-value">
              <div data-inner-test-attr="other-value">
                text
              </div>
            </section>
          </body>
        </html>`);
      return browser.visit('/data');
    });

    it('should read data attributes and values', function() {
      const section = browser.querySelector('section');
      const div = browser.querySelector('div');
      assert.equal(section.dataset.testAttr, 'fake-value');
      assert.equal(div.dataset.innerTestAttr, 'other-value');
    });
  });

  after(function() {
    browser.destroy();
  });
})
