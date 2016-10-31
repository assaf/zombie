const assert      = require('assert');
const brains      = require('./helpers/brains');
const Browser     = require('../src');
const File        = require('fs');
const Fetch       = require('../src/fetch');
const Path        = require('path');
const thirdParty  = require('./helpers/thirdparty');
const Zlib        = require('zlib');


describe('Resources', function() {
  const browser = new Browser();

  before(function() {
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


  describe('deflate', function() {
    before(function() {
      brains.get('/resources/deflate', function(req, res) {
        res.setHeader('Transfer-Encoding', 'deflate');
        const image = File.readFileSync(Path.join(__dirname, '/data/zombie.jpg'));
        Zlib.deflate(image, function(error, buffer) {
          res.send(buffer);
        });
      });
    });

    it('should uncompress deflated response with transfer-encoding', async function() {
      const response  = await browser.fetch('http://example.com/resources/deflate');
      const body      = await response.arrayBuffer().then(Buffer);
      const image     = File.readFileSync(Path.join(__dirname, '/data/zombie.jpg'));
      assert.deepEqual(image, body);
    });
  });


  describe('deflate content', function() {
    before(function() {
      brains.get('/resources/deflate', function(req, res) {
        res.setHeader('Content-Encoding', 'deflate');
        const image = File.readFileSync(Path.join(__dirname, '/data/zombie.jpg'));
        Zlib.deflate(image, function(error, buffer) {
          res.send(buffer);
        });
      });
    });

    it('should uncompress deflated response with content-encoding', async function() {
      const response  = await browser.fetch('http://example.com/resources/deflate');
      const body      = await response.arrayBuffer().then(Buffer);
      const image     = File.readFileSync(Path.join(__dirname, '/data/zombie.jpg'));
      assert.deepEqual(image, body);
    });
  });


  describe('gzip', function() {
    before(function() {
      brains.get('/resources/gzip', function(req, res) {
        res.setHeader('Transfer-Encoding', 'gzip');
        const image = File.readFileSync(Path.join(__dirname, '/data/zombie.jpg'));
        Zlib.gzip(image, function(error, buffer) {
          res.send(buffer);
        });
      });
    });

    it('should uncompress gzipped response with transfer-encoding', async function() {
      const response  = await browser.fetch('http://example.com/resources/gzip');
      const body      = await response.arrayBuffer().then(Buffer);
      const image     = File.readFileSync(Path.join(__dirname, '/data/zombie.jpg'));
      assert.deepEqual(image, body);
    });
  });


  describe('gzip content', function() {
    before(function() {
      brains.get('/resources/gzip', function(req, res) {
        res.setHeader('Content-Encoding', 'gzip');
        const image = File.readFileSync(Path.join(__dirname, '/data/zombie.jpg'));
        Zlib.gzip(image, function(error, buffer) {
          res.send(buffer);
        });
      });
    });

    it('should uncompress gzipped response with content-encoding', async function() {
      const response  = await browser.fetch('http://example.com/resources/gzip');
      const body      = await response.arrayBuffer().then(Buffer);
      const image     = File.readFileSync(Path.join(__dirname, '/data/zombie.jpg'));
      assert.deepEqual(image, body);
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


  describe('addHandler request', function() {
    before(function() {
      browser.pipeline.addHandler(function(browser, request) { // eslint-disable-line
        return new Fetch.Response('empty', { status: 204 });
      });
      return browser.visit('/resources/resource');
    });

    it('should call the handler and use its response', function() {
      browser.assert.status(204);
      browser.assert.text('body', 'empty');
    });

    after(function() {
      // Remove handler.
      browser.pipeline.pop();
    });
  });

  describe('removeHandler request', function() {
    let pipelineHandler;
    before(function(){
      pipelineHandler = function(browser, request){
        return new Fetch.Response('empty', { status: 204 });
      }
      const pipelineLength = browser.pipeline.length;
      browser.pipeline.addHandler(pipelineHandler);
      assert.equal(browser.pipeline.length, pipelineLength+1, 'Pipeline\'s length should increase by 1 after adding a handler');
      return browser.visit('/resources/resource');
    });
    it('should remove the handler from the pipeline', function() {
      let pipelineHasHandler = false
        , pipelineHasHandlerAfter = false
        , pipelineLengthBefore = browser.pipeline.length;

      browser.assert.status(204);

      for (let i=0; i<browser.pipeline.length; i++)
        if (browser.pipeline[i] === pipelineHandler) {
            pipelineHasHandler = true;
            break;
        }
      assert(pipelineHasHandler, 'Pipeline should have a handler');
      browser.pipeline.removeHandler(pipelineHandler);
      for (let i=0; i<browser.pipeline.length; i++)
        if (browser.pipeline[i] === pipelineHandler) {
            pipelineHasHandlerAfter = true;
            break;
        }
      assert(!pipelineHasHandlerAfter, 'Pipeline should not have a handler after its removal');
      assert.equal(browser.pipeline.length, pipelineLengthBefore-1, 'Pipeline\'s length should decrease by 1 after removing a handler');
    });

    it('should not use the handler after it has been removed', function(){
      return browser.visit('/resources/resource').then(function(){
        browser.assert.status(200);
      })
    })
  });

  describe('addHandler redirect', function () {
    before(function() {
      browser.pipeline.addHandler(function(b, request) {
        if (request.url === 'http://example.com/fake')
          return Fetch.Response.redirect('http://example.com/resources/resource', 301);
        else
          return null;
      });
      browser.resources.length = 0;
      return browser.visit('/fake');
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
    });

    it('should retrieve second page', function() {
      browser.assert.status(200);
      browser.assert.text('title', 'Awesome');
    });

    after(function() {
      // Remove handler.
      browser.pipeline.pop();
    });

  });


  describe('addHandler response', function() {
    before(function() {
      browser.pipeline.addHandler(async function(b, request, response) {
        // TODO this will be better with resource.clone()
        const newResponse = new Fetch.Response('Empty', { url: response.url, status: 200 });
        newResponse.headers.set('X-Body', 'Marks Spot');
        return newResponse;
      });
      return browser.visit('/resources/resource');
    });

    it('should call the handler and use its response', function() {
      assert.equal(browser.response.headers.get('X-Body'), 'Marks Spot');
      browser.assert.text('body', 'Empty');
    });

    after(function() {
      // Remove handler.
      browser.pipeline.pop();
    });
  });


  after(function() {
    browser.destroy();
  });
});
