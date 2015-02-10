const assert      = require('assert');
const Browser     = require('../src/zombie');
const { brains }  = require('./helpers');
const File        = require('fs');
const thirdParty  = require('./helpers/thirdparty');
const Zlib        = require('zlib');


describe('Resources', function() {
  let browser;

  before(function() {
    browser = Browser.create();

    brains.static('/resources/resource', `
      <html>
        <head>
          <title>Whatever</title>
          <script src='/scripts/jquery.js'></script>
        </head>
        <body>Hello World</body>
        <script>
          document.title = 'Nice';
          $(function() { $('title').text('Awesome') })
        </script>
        <script type='text/x-do-not-parse'>
          <p>this is not valid JavaScript</p>
        </script>
      </html>`);
    return brains.ready();
  });


  describe('as array', function() {
    before(function() {
      browser.resources.length = 0;
      return browser.visit('/resources/resource');
    });

    it('should have a length', function() {
      assert.equal(browser.resources.length, 2);
    });
    it('should include loaded page', function() {
      assert.equal(browser.resources[0].response.url, 'http://example.com/resources/resource');
    });
    it('should include loaded JavaScript', function() {
      assert.equal(browser.resources[1].response.url, 'http://example.com/scripts/jquery-2.0.3.js');
    });
  });


  describe('fail URL', function() {
    before(function() {
      browser.resources.fail('/resource/resource', 'Fail!');
    });

    it('should fail the request', async function() {
      try {
        await browser.visit('/resource/resource');
        assert(false, 'Request did not fail');
      } catch (error) {
        assert.equal(error.message, 'Fail!');
      }
    });

    after(function() {
      browser.resources.restore('/resources/resource');
    });
  });

  describe("fail URL regex", function() {
    before(function() {
      browser.resources.fail(/\/resource\/resourceRegex/, "Fail!");
    });

    it("should fail the request", async function() {
      try {
        await browser.visit('/resource/resourceRegex');
        assert(false, "Request did not fail");
      } catch (error) {
        assert.equal(error.message, "Fail!");
      }
    });

    after(function() {
      browser.resources.restore('/resources/resourceRegex');
    });
  });


  describe('delay URL with timeout', function() {
    before(function() {
      browser.resources.delay('/resources/resource', 150);
      browser.visit('/resources/resource');
      return browser.wait({ duration: 90 });
    });

    it('should not load page', function() {
      assert(!browser.document.body);
    });

    describe('after delay', function() {
      before(function() {
        return browser.wait({ duration: 90 });
      });

      it('should successfully load page', function() {
        browser.assert.text('title', 'Awesome');
      });
    });

    after(function() {
      browser.resources.restore('/resources/resource');
    });
  });


  describe('mock URL', function() {
    before(function() {
      browser.resources.mock('/resources/resource', { statusCode: 204, body: 'empty' });
      return browser.visit('/resources/resource');
    });

    it('should return mock result', function() {
      browser.assert.status(204);
      browser.assert.text('body', 'empty');
    });

    describe('restore', function() {
      before(function() {
        browser.resources.restore('/resources/resource');
        return browser.visit('/resources/resource');
      });

      it('should return actual page', function() {
        browser.assert.text('title', 'Awesome');
      });
    });
  });


  describe('deflate', function() {
    before(function() {
      brains.get('/resources/deflate', function(req, res) {
        res.setHeader('Transfer-Encoding', 'deflate');
        const image = File.readFileSync(__dirname + '/data/zombie.jpg');
        Zlib.deflate(image, function(error, buffer) {
          res.send(buffer);
        });
      });
    });

    it('should uncompress deflated response with transfer-encoding', async function() {
      const response  = await browser.resources.get('http://example.com/resources/deflate');
      const image     = File.readFileSync(__dirname + '/data/zombie.jpg');
      assert.deepEqual(image, response.body);
    });
  });


  describe('deflate content', function() {
    before(function() {
      brains.get('/resources/deflate', function(req, res) {
        res.setHeader('Content-Encoding', 'deflate');
        const image = File.readFileSync(__dirname + '/data/zombie.jpg');
        Zlib.deflate(image, function(error, buffer) {
          res.send(buffer);
        });
      });
    });

    it('should uncompress deflated response with content-encoding', async function() {
      const response  = await browser.resources.get('http://example.com/resources/deflate');
      const image     = File.readFileSync(__dirname + '/data/zombie.jpg');
      assert.deepEqual(image, response.body);
    });
  });


  describe('gzip', function() {
    before(function() {
      brains.get('/resources/gzip', function(req, res) {
        res.setHeader('Transfer-Encoding', 'gzip');
        const image = File.readFileSync(__dirname + '/data/zombie.jpg');
        Zlib.gzip(image, function(error, buffer) {
          res.send(buffer);
        });
      });
    });

    it('should uncompress gzipped response with transfer-encoding', async function() {
      const response  = await browser.resources.get('http://example.com/resources/gzip');
      const image     = File.readFileSync(__dirname + '/data/zombie.jpg');
      assert.deepEqual(image, response.body);
    });
  });


  describe('gzip content', function() {
    before(function() {
      brains.get('/resources/gzip', function(req, res) {
        res.setHeader('Content-Encoding', 'gzip');
        const image = File.readFileSync(__dirname + '/data/zombie.jpg');
        Zlib.gzip(image, function(error, buffer) {
          res.send(buffer);
        });
      });
    });

    it('should uncompress gzipped response with content-encoding', async function() {
      const response  = await browser.resources.get('http://example.com/resources/gzip');
      const image     = File.readFileSync(__dirname + '/data/zombie.jpg');
      assert.deepEqual(image, response.body);
    });
  });


  describe('301 redirect URL', function() {
    before(function() {
      brains.redirect('/resources/three-oh-one', '/resources/resource', { status: 301 });
      browser.resources.length = 0;
      return browser.visit('/resources/three-oh-one');
    });

    it('should have a length', function() {
      assert.equal(browser.resources.length, 2);
    });
    it('should include loaded page', function() {
      assert.equal(browser.resources[0].response.url, 'http://example.com/resources/resource');
    });
    it('should include loaded JavaScript', function() {
      assert.equal(browser.resources[1].response.url, 'http://example.com/scripts/jquery-2.0.3.js');
    });
  });

  describe('301 redirect URL cross server', function() {
    before(async function() {
      brains.redirect('/resources/cross-server', 'http://thirdparty.test/resources', 301);
      browser.resources.length = 0;

      const other = await thirdParty();
      other.get('/resources', function(req, res) {
        res.send(`
          <html>
            <head>
              <script src='//example.com/scripts/jquery.js'></script>
            </head>
            <body></body>
          </html>`);
      });

      await browser.visit('/resources/cross-server');
    });

    it('should have a length', function() {
      assert.equal(browser.resources.length, 2);
    });
    it('should include loaded page', function() {
      assert.equal(browser.resources[0].response.url, 'http://thirdparty.test/resources');
    });
    it('should include loaded JavaScript', function() {
      assert.equal(browser.resources[1].response.url, 'http://example.com/scripts/jquery-2.0.3.js');
    });
  });


  describe('request options', function() {
    const requests = [];

    before(function() {
      brains.redirect('/resources/three-oh-one', '/resources/resource', 301);

      // Capture all requests that flow through the pipeline.
      browser.on('request', function(request) {
        requests.push(request);
      });
      browser.on('redirect', function(request, response, newRequest) {
        requests.push(newRequest);
      });
      return browser.visit('/resources/three-oh-one');
    });

    it('should include strictSSL in options for all requests', function() {
      // There will be at least the initial request and a second request to
      // follow the redirect.
      assert(requests.length >= 2);
      for (let request of requests)
        assert.strictEqual(request.strictSSL, browser.strictSSL);
    });
  });


  describe('addHandler', function() {
    before(function() {
      browser.resources.addHandler(function(request, callback) {
        callback(null, { statusCode: 204, body: 'empty' });
      });
      return browser.visit('/resources/resource');
    });

    after(function() {
      // Remove handler.
      browser.resources.pipeline.pop();
    });

    it('should call the handler and use its response', function() {
      browser.assert.status(204);
      browser.assert.text('body', 'empty');
    });
  });

  describe('addHandler redirect', function () {
    before(function() {
      browser.resources.addHandler(function(request, callback) {
        const response = {
          headers : {
            location : 'http://example.com/resources/resource'
          },
          statusCode : 301
        };

        if (request.url === 'http://example.com/fake') {
          callback(null, response);
        }
        else {
          callback();
        }
      });
      browser.resources.length = 0;
      return browser.visit('/fake');
    });

    after(function() {
      // Remove handler.
      browser.resources.pipeline.pop();
    });

    it('should have a length', function() {
      assert.equal(browser.resources.length, 2);
    });

    it('should include loaded page', function() {
      assert.equal(browser.resources[0].response.url, 'http://example.com/resources/resource');
    });

    it('should include loaded JavaScript', function() {
      assert.equal(browser.resources[1].response.url, 'http://example.com/scripts/jquery-2.0.3.js');
    });

    it('should follow the redirect', function() {
      browser.assert.redirected();
      browser.assert.status(200);
      browser.assert.text('title', 'Awesome');
    });
  });


  after(function() {
    browser.destroy();
  });
});
