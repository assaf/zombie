const assert      = require('assert');
const Browser     = require('../src/zombie');
const { brains }  = require('./helpers');


describe("Authentication", function() {
  let browser;

  before(function*() {
    browser = Browser.create();
    yield brains.ready();
  });

  describe("basic", function() {
    before(function() {
      brains.get('/auth/basic', function(req, res) {
        let auth = req.headers.authorization;
        if (auth) {
          if (auth == "Basic dXNlcm5hbWU6cGFzczEyMw==")
            res.send("<html><body>" + req.headers['authorization'] + "</body></html>");
          else
            res.send("Invalid credentials", 401);
        } else
          res.send("Missing credentials", 401);
      });
    });

    describe("without credentials", function() {
      it("should return status code 401", function*() {
        try {
          yield browser.visit("/auth/basic");
          assert(false, "browser.visit should have failed");
        } catch (error) {
          browser.assert.status(401);
        };
      });
    });

    describe("with invalid credentials", function() {
      it("should return status code 401", function*() {
        try {
          browser.authenticate('localhost:3003').basic('username', 'wrong');
          yield browser.visit("/auth/basic");
          assert(false, "browser.visit should have failed");
        } catch (error) {
          browser.assert.status(401);
        };
      });
    });

    describe("with valid credentials", function() {
      it("should have the authentication header", function*() {
        browser.authenticate('localhost:3003').basic('username', 'pass123');
        yield browser.visit("/auth/basic");
        browser.assert.text('body', 'Basic dXNlcm5hbWU6cGFzczEyMw==');
      });
    });

  });


  describe("OAuth bearer", function() {
    before(function() {
      brains.get('/auth/oauth2', function(req, res) {
        let auth = req.headers.authorization;
        if (auth) {
          if (auth == 'Bearer 12345')
            res.send("<html><body>" + req.headers['authorization'] + "</body></html>");
          else
            res.send("Invalid token", 401);
        } else
          res.send("Missing token", 401);
      });
    });

    describe("without credentials", function() {
      it("should return status code 401", function*() {
        try {
          yield browser.visit("/auth/oauth2");
          assert(false, "browser.visit should have failed");
        } catch (error) {
          browser.assert.status(401);
        };
      });
    });

    describe("with invalid credentials", function() {
      it("should return status code 401", function*() {
        try {
          browser.authenticate('localhost:3003').bearer('wrong');
          yield browser.visit("/auth/oauth2");
          assert(false, "browser.visit should have failed");
        } catch (error) {
          browser.assert.status(401);
        };
      });
    });

    describe("with valid credentials", function() {
      it("should have the authentication header", function*() {
        browser.authenticate('localhost:3003').bearer('12345');
        yield browser.visit("/auth/oauth2");
        browser.assert.text('body', 'Bearer 12345');
      });
    });

  });


  describe("Scripts on secure pages", function() {
    before(function() {
      brains.get('/auth/script', function(req, res) {
        let auth = req.headers.authorization;
        if (auth) {
          res.send("\
          <html>\
            <head>\
              <title>Zero</title>\
              <script src='/auth/script.js'></script>\
            </head>\
            <body></body>\
          </html>\
          ");
        } else
          res.send("No Credentials on the html page", 401);
      });

      brains.get('/auth/script.js', function(req, res) {
        let auth = req.headers.authorization;
        if (auth)
          res.send("document.title = document.title + 'One'");
        else
          res.send("No Credentials on the javascript", 401);
      });
    });

    it("should download the script", function*() {
      browser.authenticate('localhost:3003').basic('username', 'pass123');
      yield browser.visit('/auth/script');
      browser.assert.text('title', "ZeroOne");
    });

  });

  after(function() {
    browser.destroy();
  });
});
