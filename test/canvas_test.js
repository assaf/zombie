const assert  = require('assert');
const brains  = require('./helpers/brains');
const Browser = require('../src');

describe('Canvas', function() {
  const browser = new Browser();

  before(function() {
    brains.static('/canvas', `
      <html>
        <body>
          <canvas id="myCanvas" width="1" height="2"></canvas>
        </body>
      </html>`);

    return brains.ready();
  });

  before(async function() {
    await browser.visit('/canvas');
  });

  it('should query by tag name', function() {
    browser.assert.element('canvas');
  });

  it('should query by id', function() {
    browser.assert.element('#myCanvas');
  });

  it('should have width and height attributes', function() {
    browser.assert.attribute('canvas', 'width', 1);
    browser.assert.attribute('canvas', 'height', 2);
  });

  describe('node-canvas', function() {
    try {
      require.resolve('canvas');
    } catch (e) {
      before(function() { this.skip(); });
    }

    it('should draw red rectangle', function() {
      browser.assert.evaluate(function() {
        let c = browser.query('canvas');
        let ctx = c.getContext('2d');
        ctx.fillStyle = 'red';
        ctx.fillRect(0,0,1,2);
        return ctx.getImageData(0,0,1,1).data;
      }, [255, 0, 0, 255]);
    });

    it('should have reference to element in ctx.canvas', function() {
      browser.assert.evaluate(function() {
        let c = browser.query('canvas');
        let ctx = c.getContext('2d');
        return ctx.canvas === c;
      });
    });
  });

  after(function() {
    browser.destroy();
  });

});
