const assert  = require('assert');
const brains  = require('./helpers/brains');
const Browser = require('../src');


describe('Window', function() {
  const browser = new Browser();

  before(function() {
    brains.static('/storage', '<html></html>');
    return brains.ready();
  });

  function addTests(getStorage) {

    describe('initial', function() {
      let storage;

      before(async function() {
        await browser.visit('/storage');
        storage = getStorage(browser.window);
      });

      it('should start with no keys', function() {
        assert.equal(storage.length, 0);
      });
      it('should handle key() with no key', function() {
        assert(!storage.key(1));
      });
      it('should handle getItem() with no item', function() {
        assert.equal(storage.getItem('nosuch'), null);
      });
      it('should handle removeItem() with no item', function() {
        assert.doesNotThrow(function() {
          storage.removeItem('nosuch');
        });
      });
      it('should handle clear() with no items', function() {
        assert.doesNotThrow(function() {
          storage.clear();
        });
      });
    });


    describe('add some items', function() {
      let storage;

      before(async function() {
        await browser.visit('/storage');
        storage = getStorage(browser.window);
        storage.setItem('is', 'hungry');
        storage.setItem('wants', 'brains');
      });

      it('should count all items in length', function() {
        assert.equal(storage.length, 2);
      });
      it('should make key available', function() {
        const keys = [storage.key(0), storage.key(1)].sort();
        assert.deepEqual(keys, ['is', 'wants']);
      });
      it('should make value available', function() {
        assert.equal(storage.getItem('is'), 'hungry');
        assert.equal(storage.getItem('wants'), 'brains');
      });
    });


    describe('change an item', function() {
      let storage;

      before(async function() {
        await browser.visit('/storage');
        storage = getStorage(browser.window);
        storage.setItem('is', 'hungry');
        storage.setItem('wants', 'brains');
        storage.setItem('is', 'dead');
      });

      it('should leave length intact', function() {
        assert.equal(storage.length, 2);
      });
      it('should keep key position', function() {
        const keys = [storage.key(0), storage.key(1)].sort();
        assert.deepEqual([storage.key(0), storage.key(1)].sort(), keys);
      });
      it('should change value', function() {
        assert.equal(storage.getItem('is'), 'dead');
      });
      it('should not change other values', function() {
        assert.equal(storage.getItem('wants'), 'brains');
      });
    });


    describe('remove an item', function() {
      let storage;

      before(async function() {
        await browser.visit('/storage');
        storage = getStorage(browser.window);
        storage.setItem('is', 'hungry');
        storage.setItem('wants', 'brains');
        storage.removeItem('is');
      });

      it('should drop item from length', function() {
        assert.equal(storage.length, 1);
      });
      it('should forget key', function() {
        assert.equal(storage.key(0), 'wants');
        assert(!storage.key(1));
      });
      it('should forget value', function() {
        assert.equal(storage.getItem('is'), null);
        assert.equal(storage.getItem('wants'), 'brains');
      });
    });


    describe('clean all items', function() {
      let storage;

      before(async function() {
        await browser.visit('/storage');
        storage = getStorage(browser.window);
        storage.setItem('is', 'hungry');
        storage.setItem('wants', 'brains');
        storage.clear();
      });

      it('should reset length to zero', function() {
        assert.equal(storage.length, 0);
      });
      it('should forget all keys', function() {
        assert(!storage.key(0));
      });
      it('should forget all values', function() {
        assert.equal(storage.getItem('is'), null);
        assert.equal(storage.getItem('wants'), null);
      });
    });


    describe('store null', function() {
      let storage;

      before(async function() {
        await browser.visit('/storage');
        storage = getStorage(browser.window);
        storage.setItem('null', null);
      });

      it('should store that item', function() {
        assert.equal(storage.length, 1);
      });
      it('should return null for key', function() {
        assert.equal(storage.getItem('null'), null);
      });
    });


  }


  describe('local storage', function() {
    function getStorage(window) {
      return window.localStorage;
    }
    addTests.call(this, getStorage);
  });

  describe('session storage', function() {
    function getStorage(window) {
      return window.sessionStorage;
    }
    addTests.call(this, getStorage);
  });



  after(function() {
    browser.destroy();
  });
});

