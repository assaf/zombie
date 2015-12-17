const brains  = require('./helpers/brains');
const Browser = require('../src');


describe('Facebook login with SDK test', function(){
    const browser = new Browser();
    
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
      
    it('should visit the facebook login page', async function(){
        this.timeout(5000);
        await browser.visit('/facebook');
        console.log(browser.html());
    });
});
