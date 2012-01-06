{ Vows, assert, brains, Browser } = require("./helpers")


JQUERY_VERSIONS = ["1.4.4", "1.5.1", "1.6.3", "1.7.1"]

batch = {}
for version in JQUERY_VERSIONS
  do (version)->
    brains.get "/compat/jquery-#{version}", (req, res)->
      res.send """
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
      lines = ([key, value].join("=") for key, value of req.body)
      res.send lines.join("\n")

    batch[version] =
      topic: ->
        browser = new Browser
        browser.wants "http://localhost:3003/compat/jquery-#{version}", @callback
      "selecting an option in a select element":
        topic: (browser)->
          browser.select "select", "1"
          @callback null, browser
        "should fire the change event": (browser)->
          assert.equal browser.text("#option"), "1"

      "jQuery.post":
        topic: (browser)->
          browser.clickLink "Post", @callback
        "should perform an AJAX POST request": (browser)->
          assert.match browser.text("#response"), /foo=bar/

      "jQuery.globalEval": (browser) ->
          browser.evaluate("(function () {
            $.globalEval('var globalEvalWorks = true;');
          })();")
          assert.ok browser.window.globalEvalWorks

Vows.describe("Compatibility with jQuery").addBatch(batch).export(module)
