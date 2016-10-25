const brains  = require('./helpers/brains');
const Browser = require('../src');
const assert  = require('assert');

describe('Facebook login with SDK test', function(){
    
    //create a test user in the app's dashboard
    const facebookLogin = 'nancy_najetmd_romanberg@tfbnw.net';
    const facebookPass = '1450464323';
    const facebookId = '103059683402561';
    
    const browser = new Browser();
    browser.silent = true;
    
    before(function(){
        return brains.ready();
    });
    
    before(function() {
      brains.static('/facebook', `
        <!doctype html>
        <html>
        <head>
        <title>Zombie Facebook Test</title>
        <script>
          window.fbAsyncInit = function() {
            FB.init({
              appId      : '1293201667373751',
              xfbml      : true,
              version    : 'v2.5'
            });
          };
        
          (function(d, s, id){
             var js, fjs = d.getElementsByTagName(s)[0];
             if (d.getElementById(id)) {return;}
             js = d.createElement(s); js.id = id;
             js.src = "/scripts/fb_sdk_debug_2.5.js";
             fjs.parentNode.insertBefore(js, fjs);
           }(document, 'script', 'facebook-jssdk'));
        </script>
        </head>
        <body>
        </body>
        </html>`);
    })
    let initialWindow;
    it('should visit the facebook login page', async function(){
        this.timeout(5000);
        await browser.visit('/facebook');
        initialWindow = browser.window;
        //console.log(browser.html());
    });
    it('should include fb-root element on the page', function(){
        browser.assert.element('#fb-root');
    });
    it('should have FB object', function(){
        assert(browser.window.FB);
    })
    it('should open a new window to sign in into facebook', async function(){
        browser.window.FB.login(null, {scope:'email', return_scopes: true});
        await browser.wait(1000);
        browser.assert.element('form#login_form');
        browser.assert.element('form#login_form input#email');
        browser.assert.element('form#login_form input#pass');
    });
    it('should be able to login into facebook by filling in the details', async function(){
        browser.fill('#email', facebookLogin);
		browser.fill('#pass', facebookPass);
        
        await browser.pressButton('#login_form input[type=submit]');
        assert(browser.tabs.length = 1);
        assert(browser.window == initialWindow);
        assert(browser.window.FB.getUserID() == facebookId);      
    })
});
