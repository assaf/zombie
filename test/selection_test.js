const assert      = require('assert');
const Browser     = require('../src');
const { brains }  = require('./helpers');


describe('Selection', function() {
  const browser = new Browser();

  before(function() {
    brains.static('/browser/walking', `
      <html>
        <head>
          <script src="/scripts/jquery.js"></script>
          <script src="/scripts/sammy.js"></script>
          <script src="/browser/app.js"></script>
        </head>
        <body>
          <div id="main">
            <a href="/browser/dead">Kill</a>
            <form action="#/dead" method="post">
              <label>Email <input type="text" name="email"></label>
              <label>Password <input type="password" name="password"></label>
              <button>Sign Me Up</button>
            </form>
          </div>
          <div class="now">Walking Aimlessly</div>
          <button>Do not press!</button>
        </body>
      </html>`);

    brains.static('/browser/app.js', `
      Sammy('#main', function(app) {
        app.get('#/', function(context) {
          document.title = 'The Living';
        });
        app.get('#/dead', function(context) {
          context.swap('The Living Dead');
        });
        app.post('#/dead', function(context) {
          document.title = 'Signed up';
        });
      });
      $(function() { Sammy('#main').run('#/'); });
    `);

    return brains.ready();
  });

  before(function() {
    return browser.visit('/browser/walking');
  });


  describe('queryAll', function() {
    it('should return array of nodes', function() {
      const nodes = browser.queryAll('.now');
      assert.equal(nodes.length, 1);
    });
  });

  describe('query method', function() {
    it('should return single node', function() {
      const node = browser.query('.now');
      assert.equal(node.tagName, 'DIV');
    });
  });

  describe('the tricky ID', function() {
    let root;
    before(function() {
      root = browser.document.getElementById('main');
    });

    it('should find child from id', function() {
      const nodes = root.querySelectorAll('#main button');
      assert.equal(nodes.item(0).textContent, 'Sign Me Up');
    });

    it('should find child from parent', function() {
      const nodes = root.querySelectorAll('button');
      assert.equal(nodes[0].textContent, 'Sign Me Up');
    });

    it('should not re-find element itself', function() {
      const nodes = root.querySelectorAll('#main');
      assert.equal(nodes.length, 0);
    });

    it('should not find children of siblings', function() {
      const nodes = root.querySelectorAll('button');
      assert.equal(nodes.length, 1);
    });
  });

  describe('query text', function() {
    it('should query from document', function() {
      assert.equal(browser.text('.now'), 'Walking Aimlessly');
    });
    it('should query from context (exists)', function() {
      assert.equal(browser.text('.now'), 'Walking Aimlessly');
    });
    it('should query from context (unrelated)', function() {
      assert.equal(browser.text('.now', browser.querySelector('form')), '');
    });
    it('should combine multiple elements', function() {
      assert.equal(browser.text('form label'), 'Email Password');
    });
  });

  describe('query html', function() {
    it('should query from document', function() {
      assert.equal(browser.html('.now'), `<div class="now">Walking Aimlessly</div>`);
    });
    it('should query from context (exists)', function() {
      assert.equal(browser.html('.now', browser.body), `<div class="now">Walking Aimlessly</div>`);
    });
    it('should query from context (unrelated)', function() {
      assert.equal(browser.html('.now', browser.querySelector('form')), '');
    });
    it('should combine multiple elements', function() {
      assert.equal(browser.html('title, #main a'), `<title>The Living</title><a href="/browser/dead">Kill</a>`);
    });
  });


  describe('button', function() {
    describe('when passed a valid HTML element', function() {
      it('should return the already queried element', function() {
        const elem = browser.querySelector('button');
        assert.equal(browser.button(elem), elem);
      });
    });

    describe('when passed a text on button', function() {
      it('should return the button with equally text content', function() {
        const elem = browser.querySelector('.now + button');
        assert.equal(browser.button('Do not press!'), elem);
      });
    });
  });

  describe('link', function() {
    describe('when passed a valid HTML element', function() {
      it('should return the already queried element', function() {
        const elem = browser.querySelector('a:first-child');
        assert.equal(browser.link(elem), elem);
      });
    });
  });

  describe('field', function() {
    describe('when passed a valid HTML element', function() {
      it('should return the already queried element', function() {
        const elem = browser.querySelector('input[name="email"]');
        assert.equal(browser.field(elem), elem);
      });
    });
  });


  describe('jQuery', function() {
    let $;
    before(function() {
      $ = browser.evaluate('window.jQuery');
    });

    it('should query by id', function() {
      assert.equal($('#main').size(), 1);
    });
    it('should query by element name', function() {
      assert.equal($('form').attr('action'), '#/dead');
    });
    it('should query by element name (multiple)', function() {
      assert.equal($('label').size(), 2);
    });
    it('should query with descendant selectors', function() {
      assert.equal($('body #main a').text(), 'Kill');
    });
    it('should query in context', function() {
      assert.equal($('body').find('#main a', 'body').text(), 'Kill');
    });
    it('should query in context with find()', function() {
      assert.equal($('body').find('#main a').text(), 'Kill');
    });
  });


  after(function() {
    browser.destroy();
  });

});

