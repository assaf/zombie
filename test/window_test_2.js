const assert  = require('assert');
const brains  = require('./helpers/brains');
const Browser = require('../src');


describe('My Window', async function() {
  const browser = new Browser();

  before(async function() {
    brains.static('/window/initial', `
      <!DOCTYPE html>
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
        </script>
      </body>
      </html>
    `);
    brains.static('/window/opened', `
      <!DOCTYPE html>
      <html>
      <head>
        <title>Opened Window</title>
      </head>
      <body>
        <form action="/window/opened/echo">
          <input type="text" name="name"></input>
          <input type="submit" value="submit">
        </form>
        <a href="/window/navigated" id="navigate">navigate</a>
        <a href="#" id="close">close</a>
        <script>
          document.getElementById('close').onclick = function(){
            window.close();
          }
        </script>
      </body>
      </html>
    `);
    brains.static('/window/opened/echo', `
      <!DOCTYPE html>
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
      <!DOCTYPE html>
      <html>
      <head>
        <title>Navigated Window</title>
      </head>
      <body>
        Brains!
      </body>
      </html>
    `);
    await brains.ready();
    await browser.visit('/window/initial');
  });
  
  
  it('should open a new window and switch to it', async function(){
    browser.tabs.closeAll();
    await browser.visit('/window/initial');
    const initialWindow = browser.window;
    
    await browser.clickLink('#open');
    assert(browser.tabs.length == 2); //should open a new tab
    assert(/window\/opened$/.test(browser.window._request.url));
    assert(browser.window.opener == initialWindow);
    assert(browser._eventLoop.active == browser.window);
  })
  
  it('should remember the opener after clicking on a link in an opened window', async function(){
    browser.tabs.closeAll();
    await browser.visit('/window/initial'); //start over
    const initialWindow = browser.window;
    
    await browser.clickLink('#open');
    const openedWindow = browser.window;
    
    await browser.clickLink('#navigate');
    assert(browser.tabs.length == 2); //should not open a new tab
    assert(/window\/navigated$/.test(browser.window._request.url));
    assert(browser.window._history.first.window == openedWindow);
    assert(browser.window._history.current.window == browser.window);
    assert(browser._eventLoop.active == browser.window);
    assert(browser.window.opener == initialWindow); //fail!
    
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
    assert(/window\/opened\/echo/.test(browser.window._request.url));
    assert(browser.window._history.first.window == openedWindow);
    assert(browser.window._history.current.window == browser.window);
    assert(browser.window.opener == initialWindow); //pass!
    
  });
  
});

