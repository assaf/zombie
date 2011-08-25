require "./helpers"
{ vows: vows, assert: assert, zombie: zombie, brains: brains } = require("vows")
jsdom = require("jsdom")

JQUERY_VERSIONS = ["1.4.4", "1.5.1", "1.6.2"]

for version in JQUERY_VERSIONS
  do (version)->
    console.log version
    brains.get "/compat/jquery-#{version}", (req, res)-> res.send """
      <html>
        <head>
          <title>jQuery #{version}</title>
          <script src="/jquery-#{version}.js"></script>
        </head>
        <body>
          <select>
            <option>None</option>
            <option value="1">One</option>
          </select>

          <span id="option"></span>

          <a href="#post">Post</a>

          <div id="response"></div>
        </body>

        <script>
          $(function() {

            $("select").bind("change", function() {
              $("#option").text(this.value);
            });

            $("a[href='#post']").click(function() {
              $.post("/compat/echo/jquery-#{version}", {"foo": "bar"}, function(response) {
                $("#response").text(response);
              });

              return false;
            });
          });
        </script>
      </html>
      """

    brains.post "/compat/echo/jquery-#{version}", (req, res)->
      lines = for key, value of req.body
        key + "=" + value
      res.send lines.join("\n")


vows.describe("Compatibility with jQuery").addBatch(
  "1.4.4":
    zombie.wants "http://localhost:3003/compat/jquery-1.4.4"
      "selecting an option in a select element":
        topic: (browser)->
          browser.select "select", "1"
          @callback null, browser
        "should fire the change event": (browser)-> assert.equal browser.text("#option"), "1"

      "jQuery.post":
        topic: (browser)->
          browser.clickLink "Post", @callback
        "should perform an AJAX POST request": (browser)->
          assert.match browser.text("#response"), /foo=bar/
).addBatch(
  "1.5.1":
    zombie.wants "http://localhost:3003/compat/jquery-1.5.1"
      "selecting an option in a select element":
        topic: (browser)->
          browser.select "select", "1"
          @callback null, browser
        "should fire the change event": (browser)-> assert.equal browser.text("#option"), "1"

      "jQuery.post":
        topic: (browser)->
          browser.clickLink "Post", @callback
        "should perform an AJAX POST request": (browser)->
          assert.match browser.text("#response"), /foo=bar/
).addBatch(
  "1.6.2":
    zombie.wants "http://localhost:3003/compat/jquery-1.6.2"
      "selecting an option in a select element":
        topic: (browser)->
          browser.select "select", "1"
          @callback null, browser
        "should fire the change event": (browser)-> assert.equal browser.text("#option"), "1"

      "jQuery.post":
        topic: (browser)->
          browser.clickLink "Post", @callback
        "should perform an AJAX POST request": (browser)->
          assert.match browser.text("#response"), /foo=bar/
).export(module)
