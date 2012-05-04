{ assert, brains, Browser } = require("./helpers")


describe "Facebook Connect", ->

  browser = new Browser()

  before (done)->
    brains.get "/browser/facebook", (req, res)->
      res.send """
      <html>
        <head>
          <script>
            window.fbAsyncInit = function() {
              FB.init({
                appId      : "190950381025985",
                status     : true, 
                cookie     : true,
                xfbml      : true,
                oauth      : true,
              });
              document.getElementById("connect").addEventListener("click", function(event) {
                event.preventDefault();
                window.FB.login(function(response) {
                  console.log(response)
                })
              })
            };
            (function(d){
               var js, id = 'facebook-jssdk'; if (d.getElementById(id)) {return;}
               js = d.createElement('script'); js.id = id; js.async = true;
               js.src = "//connect.facebook.net/en_US/all.js";
               d.getElementsByTagName('head')[0].appendChild(js);
             }(document));
          </script>
        </head>
        <body>
          <div id="fb-root"></div>
          <a id="connect">Connect</a>
        </body>
      </html>
      """

    brains.ready done

  before (done)->
    browser.visit "http://localhost:3003/browser/facebook", ->
      browser.clickLink "Connect", done

  it "should show FB Connect login form", ->
    assert browser.query(".login_form_container #loginform")
