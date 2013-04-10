{ assert, brains, Browser } = require("./helpers")


describe "Facebook Connect", ->

  browser = null
  before (done)->
    browser = Browser.create()
    brains.ready(done)

  before ->
    brains.get "/facebook", (req, res)->
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
                channelUrl : "http://localhost:3003/facebook/channel"
              });
              document.getElementById("connect").addEventListener("click", function(event) {
                event.preventDefault();
                window.FB.login(function(response) {
                  window.connected = response.authResponse;
                })
              })
              var authResponse = window.FB.getAuthResponse();
              if (authResponse)
                window.connected = authResponse;
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

  before (done)->
    browser.visit("http://localhost:3003/facebook")
      .then ->
        browser.clickLink "Connect"
      .then(done, done)

  it "should show FB Connect login form", ->
    browser.assert.element ".login_form_container #loginform"

  describe "login", ->
    before (done)->
      browser.fill("email", "---").fill("pass", "---")
      browser.pressButton("login", done)

    it "should show permission dialog", ->
      browser.assert.attribute "#platform_dialog_content #grant_clicked input", "value", "Log In with Facebook"

    describe.skip "authorize", ->
      before (done)->
        # all.js sets a callback with a different ID on each run.  Our
        # HTTP/S responses were captured with the callback ID f42febd2c.
        # So we cheat by using this ID and linking it to whatver callback
        # was registered last.
        FB = browser.tabs[0].FB
        for id, fn of FB.XD._callbacks
          FB.XD._callbacks["f42febd2c"] = fn
        browser.pressButton("Log In with Facebook")
        browser.wait duration: "0.5s", ->
          # Go back to the first window
          browser.close()
          done()

      it "should log user in", ->
        assert.equal browser.window.connected.userID, "100001620738919"
        assert browser.window.connected.accessToken


  after ->
    browser.destroy()
