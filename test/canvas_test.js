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


  it('should draw red rectangle (requires node-canvas)', function() {
    try {
      require.resolve('canvas');
    } catch (e) {
      this.skip();
    }

    browser.assert.evaluate(function() {
      var c = browser.query('canvas');
      var ctx = c.getContext('2d');
      ctx.fillStyle = 'red';
      ctx.fillRect(0,0,1,2);
      return ctx.getImageData(0,0,1,1).data;
    }, [255, 0, 0, 255]);
  });

  after(function() {
    browser.destroy();
  });

});
