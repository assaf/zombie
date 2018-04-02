const assert  = require('assert');
const brains  = require('./helpers/brains');
const Browser = require('../src');


describe('Document', function() {
  const browser = new Browser();

  before(function() {
    return brains.ready();
  });

  describe('character encoding', function() {
    before(function() {
      brains.get('/document/encoding', function(req, res) {
        res.header('Content-Type', 'text/html; charset=iso-8859-7');
        const open  = new Buffer('<html><body>');
        const text  = new Buffer([0xC3, 0xE5, 0xE9, 0xDC]);
        const close = new Buffer('</body></html>');
        const page  = Buffer.concat([open, text, close]);
        res.send(page);
      });
      return browser.visit('/document/encoding');
    });

    it('should support greek', function() {
      browser.assert.text('body', 'Γειά');
    });
  });


  describe('activeElement', function() {
    before(function() {
      brains.static('/document/activeElement', `
        <html>
          <body></body>
        </html>`);
      return browser.visit('/document/activeElement');
    });

    it('should be document body', function() {
      browser.assert.hasFocus(undefined);
    });

    describe('autofocus on div', function() {
      before(async function() {
        await browser.visit('/document/activeElement');
        const div = browser.document.createElement('div');
        div.setAttribute('autofocus', true);
        browser.document.body.appendChild(div);
      });

      it('should not change active element', function() {
        browser.assert.hasFocus(undefined);
      });
    });

    describe('autofocus on input', function() {
      let input;

      before(async function() {
        await browser.visit('/document/activeElement');
        input = browser.document.createElement('input');
        input.setAttribute('autofocus');
        browser.document.body.appendChild(input);
      });

      it('should change active element', function() {
        browser.assert.hasFocus(input);
      });
    });

    describe('autofocus on textarea', function() {
      let textarea;

      before(async function() {
        await browser.visit('/document/activeElement');
        textarea = browser.document.createElement('textarea');
        textarea.setAttribute('autofocus');
        browser.document.body.appendChild(textarea);
      });

      it('should change active element', function() {
        browser.assert.hasFocus(textarea);
      });
    });

    describe('focus on div', function() {
      before(async function() {
        await browser.visit('/document/activeElement');
        const div = browser.document.createElement('div');
        browser.document.body.appendChild(div);
        div.focus();
      });

      it('should change active element', function() {
        browser.assert.hasFocus(undefined);
      });
    });

    describe('focus on input', function() {
      let input;

      before(async function() {
        await browser.visit('/document/activeElement');
        input = browser.document.createElement('input');
        browser.document.body.appendChild(input);
        input.focus();
      });

      it('should change active element', function() {
        browser.assert.hasFocus(input);
      });
    });

    describe('focus on textarea', function() {
      let textarea;

      before(async function() {
        await browser.visit('/document/activeElement');
        textarea = browser.document.createElement('input');
        browser.document.body.appendChild(textarea);
        textarea.focus();
      });

      it('should change active element', function() {
        browser.assert.hasFocus(textarea);
      });
    });
  });


  describe('insertAdjacentHTML', function() {
    before(function() {
      brains.static('/document/insertAdjacentHTML', '<html><body><div><p id="existing"></p></div></body></html>');
    });

    describe('beforebegin', function() {
      let div;

      before(async function() {
        await browser.visit('/document/insertAdjacentHTML');
        div = browser.query('div');
        div.insertAdjacentHTML('beforebegin', '<p id="beforebegin"></p>');
      });

      it('should insert content before target element', function() {
        assert.equal(browser.body.firstChild.getAttribute('id'), 'beforebegin');
      });
    });

    describe('afterbegin', function() {
      let div;

      before(async function() {
        await browser.visit('/document/insertAdjacentHTML');
        div = browser.query('div');
        div.insertAdjacentHTML('afterbegin', '<p id="afterbegin"></p>');
      });

      it('should insert content as the first child within target element', function() {
        assert.equal(div.firstChild.getAttribute('id'), 'afterbegin');
      });
    });

    describe('beforeend', function() {
      let div;

      before(async function() {
        await browser.visit('/document/insertAdjacentHTML');
        div = browser.query('div');
        div.insertAdjacentHTML('beforeend', '<p id="beforeend"></p>');
      });

      it('should insert content as the last child within target element', function() {
        assert.equal(div.lastChild.getAttribute('id'), 'beforeend');
      });
    });

    describe('afterend', function() {
      let div;

      before(async function() {
        await browser.visit('/document/insertAdjacentHTML');
        div = browser.query('div');
        div.insertAdjacentHTML('afterend', '<p id="afterend"></p>');
      });

      it('should insert content after the target element', function() {
        assert.equal(browser.body.lastChild.getAttribute('id'), 'afterend');
      });
    });
  });


  describe('document.scripts', function() {
    let scripts;

    before(async function() {
      brains.static('/document/scripts', `
        <html>
          <head>
            <script src='/scripts/jquery.js'></script>
          </head>
          <body>
            <script>eval(1)</script>
            <script id='foo' src='/scripts/jquery.js?foo'></script>
          </body>
        </html>`);
      await browser.visit('/document/scripts');
      scripts = browser.document.scripts;
    });

    it('should act link an array', function() {
      assert.equal(scripts.length, 3);
      assert.equal(scripts[0].src, 'http://example.com/scripts/jquery.js');
      assert.equal(scripts.foo.src, 'http://example.com/scripts/jquery.js?foo');
    });

    it('should be an HTMLCollection', function() {
      assert.equal(scripts.length, 3);
      assert.equal(scripts.item(0).src, 'http://example.com/scripts/jquery.js');
      assert.equal(scripts.namedItem('foo').src, 'http://example.com/scripts/jquery.js?foo');
    });

    it('should find all scripts in document', function() {
      assert.equal(scripts[0].src, 'http://example.com/scripts/jquery.js');
      assert.equal(scripts[1].src, '');
      assert.equal(scripts[2].src, 'http://example.com/scripts/jquery.js?foo');
    });
  });


  after(function() {
    browser.destroy();
  });
});
