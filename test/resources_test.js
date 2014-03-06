const assert      = require('assert');
const Browser     = require('../src/zombie');
const { brains }  = require('./helpers');
const File        = require('fs');
const Zlib        = require('zlib');


describe("Resources", function() {
  let browser;

  before(function*() {
    browser = Browser.create();
    yield brains.ready();

    brains.get('/resources/resource', function(req, res) {
      res.send("\
        <html>\
          <head>\
            <title>Whatever</title>\
            <script src='/jquery.js'></script>\
          </head>\
          <body>Hello World</body>\
          <script>\
            document.title = 'Nice';\
            $(function() { $('title').text('Awesome') })\
          </script>\
          <script type='text/x-do-not-parse'>\
            <p>this is not valid JavaScript</p>\
          </script>\
        </html>\
        ");
    });
  });


  describe("as array", function() {
    before(function*() {
      browser.resources.length = 0;
      yield browser.visit('/resources/resource');
    });

    it("should have a length", function() {
      assert.equal(browser.resources.length, 2);
    });
    it("should include loaded page", function() {
      assert.equal(browser.resources[0].response.url, 'http://example.com/resources/resource');
    });
    it("should include loaded JavaScript", function() {
      assert.equal(browser.resources[1].response.url, 'http://example.com/jquery-2.0.3.js');
    });
  });


  describe("fail URL", function() {
    before(function() {
      browser.resources.fail('/resource/resource', "Fail!");
    });

    it("should fail the request", function*() {
      try {
        yield browser.visit('/resource/resource');
        assert(false, "Request did not fail");
      } catch (error) {
        assert.equal(error.message, "Fail!");
      };
    });

    after(function() {
      browser.resources.restore('/resources/resource');
    });
  });


  describe("delay URL with timeout", function() {
    before(function*() {
      browser.resources.delay('/resources/resource', 150);
      browser.visit('/resources/resource');
      yield browser.wait({ duration: 90 });
    });

    it("should not load page", function() {
      assert(!browser.document.body);
    });

    describe("after delay", function() {
      before(function*() {
        yield browser.wait({ duration: 90 });
      });

      it("should successfully load page", function() {
        browser.assert.text('title', "Awesome");
      });
    });

    after(function() {
      browser.resources.restore('/resources/resource');
    });
  });


  describe("mock URL", function() {
    before(function*() {
      browser.resources.mock('/resources/resource', { statusCode: 204, body: "empty" });
      yield browser.visit('/resources/resource');
    });

    it("should return mock result", function() {
      browser.assert.status(204);
      browser.assert.text('body', "empty");
    });

    describe("restore", function() {
      before(function*() {
        browser.resources.restore('/resources/resource');
        yield browser.visit('/resources/resource');
      });

      it("should return actual page", function() {
        browser.assert.text('title', "Awesome");
      });
    });
  });


  describe("deflate", function() {
    before(function() {
      brains.get('/resources/deflate', function(req, res) {
        res.setHeader('Transfer-Encoding', 'deflate');
        let image = File.readFileSync(__dirname + '/data/zombie.jpg');
        Zlib.deflate(image, function(error, buffer) {
          res.send(buffer);
        });
      });
    });

    it("should uncompress deflated response with transfer-encoding", function*() {
      var response  = yield (resume)=> browser.resources.get('http://example.com/resources/deflate', resume);
      var image     = File.readFileSync(__dirname + '/data/zombie.jpg');
      assert.deepEqual(image, response.body);
    });
  });


  describe("deflate content", function() {
    before(function() {
      brains.get('/resources/deflate', function(req, res) {
        res.setHeader('Content-Encoding', 'deflate');
        let image = File.readFileSync(__dirname + '/data/zombie.jpg');
        Zlib.deflate(image, function(error, buffer) {
          res.send(buffer);
        });
      });
    });

    it("should uncompress deflated response with content-encoding", function*() {
      var response  = yield (resume)=> browser.resources.get('http://example.com/resources/deflate', resume);
      var image     = File.readFileSync(__dirname + '/data/zombie.jpg');
      assert.deepEqual(image, response.body);
    });
  });


  describe("gzip", function() {
    before(function() {
      brains.get('/resources/gzip', function(req, res) {
        res.setHeader('Transfer-Encoding', 'gzip');
        let image = File.readFileSync(__dirname + '/data/zombie.jpg');
        Zlib.gzip(image, function(error, buffer) {
          res.send(buffer);
        });
      });
    });

    it("should uncompress gzipped response with transfer-encoding", function*() {
      var response  = yield (resume)=> browser.resources.get('http://example.com/resources/gzip', resume);
      var image     = File.readFileSync(__dirname + '/data/zombie.jpg');
      assert.deepEqual(image, response.body);
    });
  });


  describe("gzip content", function() {
    before(function() {
      brains.get('/resources/gzip', function(req, res) {
        res.setHeader('Content-Encoding', 'gzip');
        let image = File.readFileSync(__dirname + '/data/zombie.jpg');
        Zlib.gzip(image, function(error, buffer) {
          res.send(buffer);
        });
      });
    });

    it("should uncompress gzipped response with content-encoding", function*() {
      var response  = yield (resume)=> browser.resources.get('http://example.com/resources/gzip', resume);
      var image     = File.readFileSync(__dirname + '/data/zombie.jpg');
      assert.deepEqual(image, response.body);
    });
  });


  describe("301 redirect URL", function() {
    before(function*() {
      brains.get('/resources/three-oh-one', function(req, res) {
        res.redirect('/resources/resource', 301);
      });
      browser.resources.length = 0;
      yield browser.visit('/resources/three-oh-one');
    });

    it("should have a length", function() {
      assert.equal(browser.resources.length, 2);
    });
    it("should include loaded page", function() {
      assert.equal(browser.resources[0].response.url, 'http://example.com/resources/resource');
    });
    it("should include loaded JavaScript", function() {
      assert.equal(browser.resources[1].response.url, 'http://example.com/jquery-2.0.3.js');
    });
  });

  describe("301 redirect URL cross server", function() {
    before(function*() {
      brains.get('/resources/3005', function(req, res) {
        res.redirect('http://example.com:3005/resources/resource', 301);
      });
      browser.resources.length = 0;
      yield (resume)=> brains.listen(3005, resume);
      yield browser.visit('/resources/3005');
    });

    it("should have a length", function() {
      assert.equal(browser.resources.length, 2);
    });
    it("should include loaded page", function() {
      assert.equal(browser.resources[0].response.url, 'http://example.com:3005/resources/resource');
    });
    it("should include loaded JavaScript", function() {
      assert.equal(browser.resources[1].response.url, 'http://example.com:3005/jquery-2.0.3.js');
    });
  });


  describe("request options", function() {
    let requests = [];

    before(function*() {
      brains.get('/resources/three-oh-one', function(req, res) {
        res.redirect('/resources/resource', 301);
      });

      // Capture all requests that flow through the pipeline.
      browser.on('request', function(request) {
        requests.push(request);
      });
      browser.on('redirect', function(request, newRequest) {
        requests.push(newRequest);
      });
      yield browser.visit('/resources/three-oh-one');
    });

    it("should include 'strictSSL' in options for all requests", function() {
      // There will be at least the initial request and a second request to
      // follow the redirect.
      assert(requests.length >= 2);
      for (let request of requests)
        assert.strictEqual(request.strictSSL, browser.strictSSL);
    });
  });


  describe("addHandler", function() {
    before(function*() {
      // WARNING: This handler is used for all remaining tests in the suite.
      browser.resources.addHandler(function(request, callback) {
        callback(null, { statusCode: 204, body: "empty" });
      });
      yield browser.visit('/resources/resource');
    });

    it("should call the handler and use its response", function() {
      browser.assert.status(204);
      browser.assert.text('body', "empty");
    });
  });


  after(function() {
    browser.destroy();
  });
});
