const assert      = require('assert');
const Browser     = require('../src/zombie');
const { brains }  = require('./helpers');


describe("Authentication", function() {
  let browser;

  before(function() {
    browser = Browser.create();
    return brains.ready();
  });

  describe("basic", function() {
    before(function() {
      brains.get('/auth/basic', function(req, res) {
        let auth = req.headers.authorization;
        if (auth) {
          if (auth == "Basic dXNlcm5hbWU6cGFzczEyMw==")
            res.send("<html><body>" + req.headers.authorization + "</body></html>");
          else
            res.status(401).send("Invalid credentials");
        } else
          res.status(401).send("Missing credentials");
      });
    });

    describe("without credentials", function() {
      it("should return status code 401", async function() {
        try {
          await browser.visit("/auth/basic");
          assert(false, "browser.visit should have failed");
        } catch (error) {
          browser.assert.status(401);
        }
        return;
      });
    });

    describe("with invalid credentials", function() {
      it("should return status code 401", async function() {
        try {
          browser.authenticate('example.com').basic('username', 'wrong');
          await browser.visit("/auth/basic");
          assert(false, "browser.visit should have failed");
        } catch (error) {
          browser.assert.status(401);
        }
        return;
      });
    });

    describe("with valid credentials", function() {
      it("should have the authentication header", async function() {
        browser.authenticate('example.com').basic('username', 'pass123');
        await browser.visit("/auth/basic");
        browser.assert.text('body', 'Basic dXNlcm5hbWU6cGFzczEyMw==');
        return;
      });
    });

  });


  describe("OAuth bearer", function() {
    before(function() {
      brains.get('/auth/oauth2', function(req, res) {
        let auth = req.headers.authorization;
        if (auth) {
          if (auth == 'Bearer 12345')
            res.send("<html><body>" + req.headers.authorization + "</body></html>");
          else
            res.status(401).send("Invalid token");
        } else
          res.status(401).send("Missing token");
      });
    });

    describe("without credentials", function() {
      it("should return status code 401", async function() {
        try {
          await browser.visit("/auth/oauth2");
          assert(false, "browser.visit should have failed");
        } catch (error) {
          browser.assert.status(401);
        }
        return;
      });
    });

    describe("with invalid credentials", function() {
      it("should return status code 401", async function() {
        try {
          browser.authenticate('example.com').bearer('wrong');
          await browser.visit("/auth/oauth2");
          assert(false, "browser.visit should have failed");
        } catch (error) {
          browser.assert.status(401);
        }
        return;
      });
    });

    describe("with valid credentials", function() {
      it("should have the authentication header", async function() {
        browser.authenticate('example.com').bearer('12345');
        await browser.visit("/auth/oauth2");
        browser.assert.text('body', 'Bearer 12345');
        return;
      });
    });

  });


  describe("Scripts on secure pages", function() {
    before(function() {
      brains.get('/auth/script', function(req, res) {
        let auth = req.headers.authorization;
        if (auth) {
          res.send(`
          <html>
            <head>
              <title>Zero</title>
              <script src='/auth/script.js'></script>
            </head>
            <body></body>
          </html>
          `);
        } else
          res.status(401).send("No Credentials on the html page");
      });

      brains.get('/auth/script.js', function(req, res) {
        let auth = req.headers.authorization;
        if (auth)
          res.send("document.title = document.title + 'One'");
        else
          res.status(401).send("No Credentials on the javascript");
      });
    });

    it("should download the script", async function() {
      browser.authenticate('example.com').basic('username', 'pass123');
      await browser.visit('/auth/script');
      browser.assert.text('title', "ZeroOne");
      return;
    });

  });

  after(function() {
    browser.destroy();
  });
});
