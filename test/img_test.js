const assert  = require('assert');
const brains  = require('./helpers/brains');
const Browser = require('../src');
const File    = require('fs');


describe('IMG', function() {
  const browser = new Browser();

  before(function() {
    brains.static('/image/index.html', `
      <html>
        <body>
          <img src="/image/zombie.jpg" />
        </body>
      </html>`);
    brains.get('/image/zombie.jpg', function(req, res) {
      res.setHeader('Content-Type', 'image/jpeg');
      res.send(File.readFileSync(`${__dirname}/data/zombie.jpg`));
    });
    return brains.ready();
  });

  before(function() {
    browser.features = 'img';
    return browser.visit('/image/index.html');
  });

  it('should have full URL in src attribute', function() {
    assert.equal(browser.query('img').src, 'http://example.com/image/zombie.jpg');
  });

  it('should have 2 resources', function() {
    assert.equal(browser.resources.length, 2);
  });

  it('should be in resources', function() {
    assert.equal(browser.resources[1].response.url, 'http://example.com/image/zombie.jpg');
  });

  it('should be the same as original file', async function() {
    assert.deepEqual(browser.resources[1].response.body, File.readFileSync(`${__dirname}/data/zombie.jpg`));
  });


  after(function() {
    browser.destroy();
  });

});
