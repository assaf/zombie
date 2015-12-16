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
        <a href="/window/navigate" id="navigate">navigate</a>
        <a href="#" id="close">close</a>
        <script>
          document.getElementById('close').onclick = function(){
            window.close();
          }
        </script>
      </body>
      </html>
    `);
    brains.static('/window/navigate', `
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
  
  it('should open a new window', async function(){
    assert(browser.tabs.length == 1);
    await browser.clickLink('#open');
    assert(browser.tabs.length == 2);
  });
  it('should remember window\'s opener', function(){
    assert(browser.tabs[1].opener == browser.tabs[0]);
  });
  it('should switch eventLoop.active to the new tab', function(){
    assert(browser._eventLoop.active == browser.tabs[1]);
  });
  it('should remember the opener after navigating the window', async function(){
    //console.log(browser.window);
    await browser.clickLink('#navigate');
    assert(browser.tabs.length == 2); //should not open a new tab
  });
});

