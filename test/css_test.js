const brains  = require('./helpers/brains');
const Browser = require('../src');


describe('CSS', function() {
  const browser = new Browser();

  before(function() {
    return brains.ready();
  });


  describe('style', function() {
    before(function() {
      brains.get('/styled', function(req, res) {
        res.send(`
          <html>
            <body>
              <div id="styled"></div>
            </body>
          </html>
       `);
      });
      return browser.visit('/styled');
    });

    it('should be formatted string', function() {
      browser.query('#styled').style.opacity = 0.55;
      browser.assert.style('#styled', 'opacity', '0.55');
    });

    it('should not accept non-numbers', function() {
      browser.query('#styled').style.opacity = '.46';
      browser.query('#styled').style.opacity = 'four-six';
      browser.assert.style('#styled', 'opacity', '0.46');
    });

    it('should default to empty string', function() {
      const style = browser.query('#styled').style;
      style.opacity = 1.0;
      style.opacity = undefined;
      browser.assert.style('#styled', 'opacity', '');
      style.opacity = 1.0;
      style.opacity = null;
      browser.assert.style('#styled', 'opacity', '');
    });
  });

  after(function() {
    browser.destroy();
  });
});
