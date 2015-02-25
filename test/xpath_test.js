const assert  = require('assert');
const brains  = require('./helpers/brains');
const Browser = require('../src');


describe('XPath', function() {
  const browser = new Browser();

  before(async function() {
    brains.get('/xpath', function(req, res) {
      res.send(`
        <html>
          <body>
            <h1 id="title">My Blog</h2>

            <ul class="navigation">
              <li><a href="#">First anchor</a></li>
              <li><a href="#">Second anchor</a></li>
              <li><a href="#">Third anchor</a></li>
              <li><a href="#">Fourth anchor</a></li>
              <li><a href="#">Fifth anchor</a></li>
            </ul>

            <div id="posts">
              <div class="post" id="post-1">
                <h2>First post</h2>

                <div class="meta">
                  <a href="#">First permalink</a>
                  <a href="#">First author</a>
                  <a href="#">First comments</a>
                </div>

                <div class="content">
                  <p>First paragraph</p>
                  <p>Second paragraph</p>
                  <p>Third paragraph</p>
                </div>
              </div>

              <div class="post" id="post-2">
                <h2>Second post</h2>

                <div class="meta">
                  <a href="#">Second permalink</a>
                  <a href="#">Second author</a>
                  <a href="#">Second comments</a>
                </div>

                <div class="content">
                  <p>Fourth paragraph</p>
                  <p>Fifth paragraph</p>
                  <p>Sixth paragraph</p>
                </div>
              </div>
            </div>
          </body>
        </html>
       `);
    });

    await brains.ready();
    await browser.visit('/xpath');
  });


  describe('evaluate nodes', function() {
    const anchors = [];

    before(function() {
      const result = browser.xpath('//a');
      let node;
      while (node = result.iterateNext())
        anchors.push(node);
    });

    it('should return eleven nodes', function() {
      assert.equal(anchors.length, 11);
    });
    it('should return first anchor', function() {
      assert.equal(anchors[0].textContent, 'First anchor');
    });
    it('should return third anchor', function() {
      assert.equal(anchors[2].textContent, 'Third anchor');
    });
  });


  describe('evaluate with id', function() {
    const nodes = [];

    before(function() {
      const result = browser.xpath('//*[@id="post-2"]/h2');
      let node;
      while (node = result.iterateNext())
        nodes.push(node);
    });

    it('should return one node', function() {
      assert.equal(nodes.length, 1);
    });
    it('should return second post title', function() {
      assert.equal(nodes[0].textContent, 'Second post');
    });
  });


  describe('evaluate number', function() {
    let result;

    before(function() {
      result = browser.xpath('count(//a)');
    });

    it('should return result type number', function() {
      assert.equal(result.resultType, result.NUMBER_TYPE);
    });
    it('should return number of nodes', function() {
      assert.equal(result.numberValue, 11);
    });
  });


  describe('evaluate string', function() {
    let result;

    before(function() {
      result = browser.xpath('"foobar"');
    });

    it('should return result type string', function() {
      assert.equal(result.resultType, result.STRING_TYPE);
    });
    it('should return number of nodes', function() {
      assert.equal(result.stringValue, 'foobar');
    });
  });


  describe('evaluate boolean', function() {
    let result;

    before(function() {
      result = browser.xpath('2 + 2 = 4');
    });

    it('should return result type boolean', function() {
      assert.equal(result.resultType, result.BOOLEAN_TYPE);
    });
    it('should return number of nodes', function() {
      assert.equal(result.booleanValue, true);
    });
  });


  describe('window', function() {
    it('should have XPathException', function() {
      assert(browser.window.XPathException);
    });

    it('should have XPathExpression', function() {
      assert(browser.window.XPathExpression);
    });

    it('should have XPathEvaluation', function() {
      assert(browser.window.XPathEvaluator);
    });

    it('should have XPathResult', function() {
      assert(browser.window.XPathResult);
    });
  });


  after(function() {
    return browser.destroy();
  });

});
