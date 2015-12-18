const assert  = require('assert');
const brains  = require('./helpers/brains');
const Browser = require('../src');

describe('Window opener property and close method', function(){
  const browser = new Browser();
  before(async function() {
      brains.static('/window/initial', `
        <html>
        <head>
          <title>Initial Window</title>
        </head>
        <body>
          <a id="open">open</a>
          <script>
            var w;
            document.getElementById('open').onclick = function(){
              w = window.open('/window/opened');
              return false;
            }
            window.addEventListener("message", function(event){
              if(event.data === 'close' && w && !w.closed){
                w.close();
              }
            }, false);
          </script>
        </body>
        </html>
      `);
      brains.static('/window/opened', `
        <html>
        <head>
          <title>Opened Window</title>
        </head>
        <body>
          <form action="/window/opened/echo">
            <input type="text" name="name">
            <input type="submit" value="submit">
          </form>
          <a href="/window/navigated" id="navigate">navigate</a>
          <a href="#" id="close">close</a>
          <script>
            document.getElementById('close').onclick = function(){
              window.close();
            }
            function postMessageToOpener(msg){
              opener.postMessage(msg, 'example.com');
            }
          </script>
        </body>
        </html>
      `);
      brains.static('/window/opened/echo', `
        <html>
        <head>
          <title>Opened Window - Submitted form</title>
        </head>
        <body>
          echo
        </body>
        </html>
      `);
      brains.static('/window/navigated', `
        <html>
        <head>
          <title>Navigated Window</title>
        </head>
        <body>
          Brains!
          <script>
            function postMessageToOpener(msg){
              opener.postMessage(msg, 'example.com');
            }
          </script>
        </body>
        </html>
      `);
      await brains.ready();
    });
  
  describe('window.close()', function(){
    let initialWindow;
    before(async function(){
      browser.tabs.closeAll();
      await browser.visit('/window/initial');
      browser.assert.url('/window/initial');
      initialWindow = browser.window;
      assert(browser._eventLoop.active == initialWindow);
      
      browser.window.setTimeout(function(){
        this.document.title += ' Timeout';
      }, 100);
    });
    it('should be able to close windows in context of opener', async function(){
      await browser.clickLink('#open');
      assert(browser.tabs.length == 2); //should open a new tab
      browser.assert.url('/window/opened');
      const openedWindow = browser.window;
      assert(openedWindow.opener == initialWindow);
      assert(initialWindow.w == openedWindow);
      assert(browser._eventLoop.active == openedWindow);
      assert(browser.tabs.current == openedWindow);
      
      initialWindow._evaluate('w.close()');
      assert(browser.tabs.length == 1); //should close the opened tab
      assert(openedWindow.closed); //close the window
    });
    it('should restore tabs.current', function(){
      assert(browser.tabs.current == initialWindow);
    });
    it('should restore _eventLoop.active', function(){
      assert(browser._eventLoop.active == initialWindow);
    });
    it('should continue eventLoop of the opener', async function(){
      await browser.wait();
      assert(/Timeout/.test(browser.window.document.title));
    });
    
    it('should close all windows in history after navigation (from opener)', async function(){
      browser.tabs.closeAll();
      await browser.visit('/window/initial');
      browser.assert.url('/window/initial');
      initialWindow = browser.window;
      
      await browser.clickLink('#open');
      assert(browser.tabs.length == 2); //should open a new tab
      browser.assert.url('/window/opened');
      let openedWindow = browser.window;
      await browser.clickLink('navigate');
      let navigatedWindow = browser.window;
      browser.assert.url('/window/navigated');
      initialWindow._evaluate('w.close()');
      assert(openedWindow.closed);
      assert(navigatedWindow.closed);
      assert(browser.tabs.length == 1);
    });
    
    it('should close all windows in history after navigation (from opened window)', async function(){
      browser.tabs.closeAll();
      await browser.visit('/window/initial');
      browser.assert.url('/window/initial');
      initialWindow = browser.window;
      
      await browser.clickLink('#open');
      assert(browser.tabs.length == 2); //should open a new tab
      browser.assert.url('/window/opened');
      let openedWindow = browser.window;
      await browser.clickLink('navigate');
      let navigatedWindow = browser.window;
      browser.assert.url('/window/navigated');
      openedWindow._evaluate(()=>{openedWindow.close()});
      assert(openedWindow.closed);
      assert(navigatedWindow.closed);
      assert(browser.tabs.length == 1);
    });
    
    it('should close all window in history after navigation (from navigated window)', async function(){
      browser.tabs.closeAll();
      await browser.visit('/window/initial');
      browser.assert.url('/window/initial');
      initialWindow = browser.window;
      
      await browser.clickLink('#open');
      assert(browser.tabs.length == 2); //should open a new tab
      browser.assert.url('/window/opened');
      let openedWindow = browser.window;
      await browser.clickLink('navigate');
      let navigatedWindow = browser.window;
      browser.assert.url('/window/navigated');
      navigatedWindow._evaluate(()=>{navigatedWindow.close()});
      assert(openedWindow.closed);
      assert(navigatedWindow.closed);
      assert(browser.tabs.length == 1);
    });
    
    it('should throw an error when waiting when no windows are open', async function(done){
      browser.tabs.closeAll();
      await browser.visit('/window/initial');
      browser.assert.url('/window/initial');
      browser.window.close();
      try{
        await browser.wait();
      }catch(err){
        assert(/No window open/.test(err.message));
        done();
        return;
      }
      done(new Error('Should have thrown an error'));
    });
    
    describe('close via postMessage', function(){
      it('should close window from opener via postMessage', async function(){
        browser.tabs.closeAll();
        await browser.visit('/window/initial');
        browser.assert.url('/window/initial');
        initialWindow = browser.window;
        
        await browser.clickLink('#open');
        assert(browser.tabs.length == 2); //should open a new tab
        browser.assert.url('/window/opened');
        let openedWindow = browser.window;
        browser.evaluate("postMessageToOpener('close')");
        assert(openedWindow.closed);
        assert(browser.tabs.length == 1); //should close the tab
      });
      
      it('should close all windows in history after navigation from opener via postMessage', async function(){
        browser.tabs.closeAll();
        await browser.visit('/window/initial');
        browser.assert.url('/window/initial');
        initialWindow = browser.window;
        
        await browser.clickLink('#open');
        assert(browser.tabs.length == 2); //should open a new tab
        browser.assert.url('/window/opened');
        let openedWindow = browser.window;
        await browser.clickLink('navigate');
        let navigatedWindow = browser.window;
        browser.assert.url('/window/navigated');
        browser.evaluate("postMessageToOpener('close')");
        assert(openedWindow.closed);
        assert(navigatedWindow.closed);
        assert(browser.tabs.length == 1);
      });
    });
    
    
    
  });
  
  describe('inherit opener', function() {
    
    before(async function(){
      browser.tabs.closeAll();
      await browser.visit('/window/initial');
    });
    
    describe('functional', function(){
      it('should open a new window and switch to it', async function(){
        browser.tabs.closeAll();
        await browser.visit('/window/initial');
        const initialWindow = browser.window;
        
        await browser.clickLink('#open');
        assert(browser.tabs.length == 2); //should open a new tab
        browser.assert.url('/window/opened');
        assert(browser.window.opener == initialWindow);
        assert(browser._eventLoop.active == browser.window);
      });
      it('should remember the opener after clicking on a link in an opened window', async function(){
        browser.tabs.closeAll();
        await browser.visit('/window/initial'); //start over
        const initialWindow = browser.window;
        
        await browser.clickLink('#open');
        const openedWindow = browser.window;
        
        await browser.clickLink('#navigate');
        assert(browser.tabs.length == 2); //should not open a new tab
        browser.assert.url('/window/navigated');
        assert(browser.window._history.first.window == openedWindow);
        assert(browser.window._history.current.window == browser.window);
        assert(browser._eventLoop.active == browser.window);
        assert(browser.window.opener == initialWindow); //pass!
        
      });
      
      it('should remember the opener after submiting a form in the window', async function(){
        browser.tabs.closeAll();
        await browser.visit('/window/initial'); //start over
        const initialWindow = browser.window;
        
        await browser.clickLink('#open');
        const openedWindow = browser.window;
        browser.fill('name', 'Zombie');
        
        await browser.pressButton('submit');
        assert(browser.tabs.length == 2); //should not open a new tab
        browser.assert.url('/window/opened/echo?name=Zombie');
        assert(browser.window._history.first.window == openedWindow);
        assert(browser.window._history.current.window == browser.window);
        assert(browser.window.opener == initialWindow); //pass!
        
      });
    });
    
    
    describe('location methods', function(){
      let initialWindow;
      before(async function(){
        browser.tabs.closeAll();
        await browser.visit('/window/initial');
        initialWindow = browser.window;
        await browser.clickLink('#open');
        browser.assert.url('/window/opened');
      });
      it('should remember opener on location.assign', async function(){
        browser.window.location.assign('/window/navigated');
        await browser.wait();
        browser.assert.url('/window/navigated');
        assert(browser.window.opener == initialWindow);
      });
      it('should remember opener on location.replace', async function(){
        browser.window.location.replace('/window/opened');
        await browser.wait();
        browser.assert.url('/window/opened');
        assert(browser.window.opener == initialWindow);
      });
      it('should remember opener on location.reload', async function(){
        browser.window.location.reload();
        await browser.wait();
        browser.assert.url('/window/opened');
        assert(browser.window.opener == initialWindow);
      });
    });
    describe('history methods', function(){
      let initialWindow;
      before(async function(){
        browser.tabs.closeAll();
        await browser.visit('/window/initial');
        initialWindow = browser.window;
        await browser.clickLink('#open');
        browser.assert.url('/window/opened');
      });
      it('should remember opener on _history.assign', async function(){
        browser.window._history.assign('/window/navigated');
        await browser.wait();
        browser.assert.url('/window/navigated');
        assert(browser.window.opener == initialWindow);
      });
      it('should remember opener on _history.replace', async function(){
        browser.window._history.replace('/window/opened');
        await browser.wait();
        browser.assert.url('/window/opened');
        assert(browser.window.opener == initialWindow);
      });
      it('should remember opener on _history.reload', async function(){
        browser.window._history.reload();
        await browser.wait();
        browser.assert.url('/window/opened');
        assert(browser.window.opener == initialWindow);
      });
    });
    
    
    describe('meta refresh tag', function(){
      before(function() {
        brains.static('/window/start_refresh', `
          <html>
            <head>
              <title>Initial Window</title>
            </head>
            <body>
              <a id="open">open refresh</a>
              <script>
                var w;
                document.getElementById('open').onclick = function(){
                  w = window.open('/window/refresh?url=/window/refreshed');
                  return false;
                }
              </script>
            </body>
          </html>
        `);
          
        brains.static('/window/refreshed', `
          <html>
            <head>
              <title>Done</title>
            <body>Redirection complete.</body>
          </html>
        `);
        brains.get('/window/refresh', function(req, res) {
          // Don't refresh page more than once
          const referrer  = req.headers.referer;
          const refreshed = referrer && referrer.endsWith('/windows/refresh');
          if (refreshed)
            res.send(`
              <html>
                <head><title>Done</title></head>
                <body></body>
              </html>
            `);
          else {
            const value = req.query.url ? `1; url=${req.query.url}` : '1'; // Refresh to URL or reload self
            res.send(`
              <html>
                <head>
                  <title>Refresh</title>
                  <meta http-equiv="refresh" content="${value}">
                </head>
                <body>
                  You are being redirected.
                </body>
              </html>
            `);
          }
        });
      });
      let initialWindow;
      
      before(async function(){
        await browser.visit('/window/start_refresh');
        browser.assert.url('/window/start_refresh');
        initialWindow = browser.window;
      });
      
      it('should remember opener if page has meta refresh tag in it', async function(){
        await browser.clickLink('#open');
        browser.assert.url('/window/refreshed');
        assert(browser.window.opener == initialWindow);
      });
    });
  });
  
});


