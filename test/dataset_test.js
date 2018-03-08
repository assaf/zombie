const assert      = require('assert');
const brains      = require('./helpers/brains');
const Browser     = require('../src');
const thirdParty  = require('./helpers/thirdparty');


describe('Data Attribute Test', function() {
  const browser = new Browser();

  before(function() {
    return brains.ready();
  });

  describe('query selector', function() {
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

  describe.only('event target', function() {
    let dataValue;
    before(async function() {
      await browser.load(`
        <html>
          <body>
            <div data-click-attr="we clicked here">
              text
            </div>
          </body>
        </html>`);

      browser.on('event', function(event, target) {
        if (event.type === 'click')
          dataValue = target.dataset.clickAttr;
      });

      browser.click('div');
      return browser.wait();
    });

    it('should read data attributes and values', function() {
      assert.equal(dataValue, 'we clicked here')
    });

  });

  describe.only('javascript event target', function() {
    let dataValue;
    before(async function() {
      await browser.load(`
        <html>
          <body>
            <div id='response'></div>
            <a href="#" data-link-attr="link attribute value">
              text
            </a>
          </body>
          <script>
            var anchor = document.querySelector('a');
            anchor.addEventListener('click', function(event){
              var value = event.target.dataset.linkAttr;
              document.querySelector('#response').text = value;
              return false;
            });
          </script>
        </html>`);

      browser.click('a');
      return browser.wait();
    });

    it('does stuff', function(){
      const div = browser.querySelector('div');
      assert(div.text, 'link attribute value')
    });
  });


  after(function() {
    browser.destroy();
  });
});
