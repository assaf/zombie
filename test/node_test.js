const assert  = require('assert');
const brains  = require('./helpers/brains');
const Browser = require('../src');


describe('Node', function() {
  const browser = new Browser();

  before(function() {
    return brains.ready();
  });


  describe('.contains', function() {
    before(function() {
      brains.static('/node/contains.html', `
        <html>
          <body>
            <div class="body-child"></div>
            <div class="parent">
              <div class="child"></div>
            </div>
          </body>
        </html>`);
    });

    before(function() {
      return browser.visit('/node/contains.html');
    });

    it('should be true for direct children', function() {
      const bodyChild = browser.query('.body-child');
      assert.strictEqual(browser.document.body.contains(bodyChild), true);
    });
  
    it('should be true for grandchild children', function() {
      const child = browser.query('.child');
      assert.strictEqual(browser.document.body.contains(child), true);
    });

    it('should be false for siblings', function() {
      const bodyChild = browser.query('.body-child');
      const parent = browser.query('.parent');
      assert.strictEqual(parent.contains(bodyChild), false);
    });

    it('should be false for parent', function() {
      const child = browser.query('.child');
      const parent = browser.query('.parent');
      assert.strictEqual(child.contains(parent), false);
    });

    it('should be false for self', function() {
      const child = browser.query('.child');
      assert.strictEqual(child.contains(child), false);
    });

  });


  after(function() {
    browser.destroy();
  });
      
});
