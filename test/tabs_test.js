const assert      = require('assert');
const Browser     = require('../src/zombie');
const { brains }  = require('./helpers');


describe('Tabs', function() {
  let browser;

  before(function() {
    browser = Browser.create();
    return brains.ready();
  });

  before(function() {
    brains.static('/tabs', `
      <html>
        <title>Brains</title>
      </html>
    `);

    browser.open({ name: 'first' });
    browser.open({ name: 'second' });
    browser.open({ name: 'third' });
    browser.open();
    browser.open('_blank');
  });


  it('should have on tab for each open window', function() {
    assert.equal(browser.tabs.length, 5);
  });

  it('should treat _blank as special name', function() {
    const names = browser.tabs.map((w)=> w.name);
    assert.deepEqual(names, ['first', 'second', 'third', '', '']);
  });

  it('should allow finding window by index number', function() {
    const window = browser.tabs[1];
    assert.equal(window.name, 'second');
  });

  it('should allow finding window by name', function() {
    const window = browser.tabs['third'];
    assert.equal(window.name, 'third');
  });

  it('should not index un-named windows', function() {
    assert(!browser.tabs['']);
    assert(!browser.tabs[null]);
    assert(!browser.tabs[undefined]);
  });

  it('should be able to select current tab by name', function() {
    browser.tabs.current = 'second';
    assert.equal(browser.window.name, 'second');
  });

  it('should be able to select current tab by index', function() {
    browser.tabs.current = 2;
    assert.equal(browser.window.name, 'third');
  })

  it('should be able to select current tab from window', function() {
    browser.tabs.current = browser.tabs[0];
    assert.equal(browser.window.name, 'first');
  });

  it('should provide index of currently selected tab', function() {
    browser.tabs.current = 'second';
    assert.equal(browser.tabs.index, 1);
    browser.tabs.current = browser.tabs[2]
    assert.equal(browser.tabs.index, 2);
  });


  describe('selecting new tab', function() {
    before(function(done) {
      browser.tabs.closeAll();
      browser.open({ name: 'first' });
      browser.open({ name: 'second' });
      browser.tabs[0].addEventListener('focus', function() {
        done();
      });
      browser.tabs.current = 0;
      browser.wait();
    });

    it('should fire onfocus event', function() {
      assert(true);
    });
  });


  describe('selecting new tab', function() {
    before(function(done) {
      browser.tabs.closeAll();
      browser.open({ name: 'first'} );
      browser.open({ name: 'second' });
      browser.tabs.current = 1;
      browser.tabs[1].addEventListener('blur', function() {
        done();
      });
      browser.tabs.current = 0;
      browser.wait();
    });

    it('should fire onblur event', function() {
      assert(true);
    });
  });


  describe('opening window with same name', function() {
    let second;

    before(function() {
      browser.tabs.closeAll();
      browser.open({ name: 'first' });
      browser.open({ name: 'second' });
      browser.open({ name: 'third' });
      second = browser.tabs.open({ name: 'second' });
    });

    it('should reuse open tab', function() {
      assert.equal(browser.tabs.length, 3);
      assert.equal(browser.tabs.index, 1);
      assert.equal(second, browser.tabs.current);
    });

    describe('and different URL', function() {
      let third;

      before(function(done) {
        third = browser.tabs.open({ name: 'third', url: 'http://example.com/tabs' });
        browser.wait(done);
      });

      it('should reuse open tab', function() {
        assert.equal(browser.tabs.length, 3);
        assert.equal(browser.tabs.index, 2);
        assert.equal(third, browser.tabs.current);
      });
      it('should navigate to new URL', function() {
        browser.assert.url('/tabs');
        browser.assert.text('title', 'Brains');
      });
    });
  });


  describe('closing window by name', function() {
    before(function() {
      browser.tabs.closeAll();
      browser.open({ name: 'first' });
      browser.open({ name: 'second' });
      browser.open({ name: 'third' });
    });

    before(function() {
      browser.tabs.close('second');
    });

    it('should close named window', function() {
      assert.equal(browser.tabs.length, 2);
      const names = browser.tabs.map((w)=> w.name);
      assert.deepEqual(names, ['first', 'third']);
    });
  });

    
  describe('closing window by index', function() {
    before(function() {
      browser.tabs.closeAll();
      browser.open({ name: 'first' });
      browser.open({ name: 'second' });
      browser.open({ name: 'third' });
    });
    before(function() {
      browser.tabs.close(1);
    });

    it('should close named window', function() {
      assert.equal(browser.tabs.length, 2);
      const names = browser.tabs.map((w)=> w.name);
      assert.deepEqual(names, ['first', 'third']);
    });
  });


  describe('closing window', function() {
    before(function() {
      browser.open({ name: 'first' });
      browser.open({ name: 'second' });
      browser.open({ name: 'third' });
      browser.tabs.current = 1;
      browser.tabs.close();
    });

    it('should navigate to previous tab', function() {
      assert.equal(browser.tabs.index, 0);
      assert.equal(browser.window.name, 'first');
    });
  });


  describe('closing all tabs', function() {
    before(function() {
      browser.tabs.closeAll();
      browser.open({ name: 'first' });
      browser.open({ name: 'second' });
      browser.open({ name: 'third' });
      browser.tabs.closeAll();
    });

    it('should leave no tabs open', function() {
      assert.equal(browser.tabs.length, 0);
      assert.equal(browser.tabs.current, null);
      assert.equal(browser.tabs.index, -1);
    });
  });


  describe('tabs array', function() {
    before(function() {
      browser.tabs.closeAll();
      browser.open({ name: 'first' });
      browser.open({ name: 'second' });
      browser.open();
    });

    it('should have keys for named windows and their index', function() {
      assert.deepEqual(Object.keys(browser.tabs), [0, 1, 2, 'first', 'second']);
    });

    it('should allow iterating through all windows', function() {
      const names = [];
      for (let window of browser.tabs)
        names.push(window.name);
      assert.deepEqual(names, ['first', 'second', '']);
    });

    it('should allow enumeration of all windows', function() {
      const names = browser.tabs.map((window)=> window.name);
      assert.deepEqual(names, ['first', 'second', '']);
    });

    it('should not shadow property with same name', function() {
      browser.open({ name: 'open' });
      assert(browser.tabs.open instanceof Function);
    });

    it('should be able to find any window by name', function() {
      assert(browser.tabs.find('open').browser);
    });
  });


  describe('new browser', function() {
    let newBrowser = null;

    before(function() {
      newBrowser = Browser.create();
    });

    it('should have no open windows', function() {
      assert(!newBrowser.window);
      assert.equal(newBrowser.tabs.length, 0);
    });

    after(function() {
      newBrowser.destroy();
    });
  });


  after(function() {
    browser.destroy();
  });

});
