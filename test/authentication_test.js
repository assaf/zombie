const brains  = require('./helpers/brains');
const Browser = require('../src');


describe('Authentication', function() {
  const browser = new Browser();

  before(function() {
    return brains.ready();
  });

  describe('basic', function() {
    before(function() {
      brains.get('/auth/basic', function(req, res) {
        const auth = req.headers.authorization;
        if (auth && auth === 'Basic dXNlcm5hbWU6cGFzczEyMw==')
          res.send(`<html><body>${req.headers.authorization}</body></html>`);
        else if (auth)
          res.status(401).send('Invalid credentials');
        else
          res.status(401).send('Missing credentials');
      });
    });

    describe('without credentials', function() {
      before(async function() {
        await browser.visit('/auth/basic').catch(()=> null);
      });

      it('should return status code 401', function() {
        browser.assert.status(401);
      });
    });

    describe('with invalid credentials', function() {
      before(async function() {
        browser.on('authenticate', function(authentication) {
          authentication.username = 'username';
          authentication.password = 'wrong';
        });
        await browser.visit('/auth/basic').catch(()=> null);
      });

      it('should return status code 401', function() {
        browser.assert.status(401);
      });
    });

    describe('with valid credentials', function() {
      before(async function() {
        browser.on('authenticate', function(authentication) {
          authentication.username = 'username';
          authentication.password = 'pass123';
        });
        await browser.visit('/auth/basic');
      });

      it('should have the authentication header', function() {
        browser.assert.text('body', 'Basic dXNlcm5hbWU6cGFzczEyMw==');
      });
    });

  });


  describe('Scripts on secure pages', function() {
    before(function() {
      brains.get('/auth/script', function(req, res) {
        const auth = req.headers.authorization;
        if (auth)
          res.send(`
          <html>
            <head>
              <title>Zero</title>
              <script src='/auth/script.js'></script>
            </head>
            <body></body>
          </html>
          `);
        else
          res.status(401).send('No Credentials on the html page');
      });

      brains.get('/auth/script.js', function(req, res) {
        const auth = req.headers.authorization;
        if (auth)
          res.send('document.title = document.title + "One"');
        else
          res.status(401).send('No Credentials on the javascript');
      });
    });

    before(async function() {
      browser.on('authenticate', function(authentication) {
        authentication.username = 'username';
        authentication.password = 'pass123';
      });

      await browser.visit('/auth/script');
    });

    it('should download the script', function() {
      browser.assert.text('title', 'ZeroOne');
    });

  });

  after(function() {
    browser.destroy();
  });
});
