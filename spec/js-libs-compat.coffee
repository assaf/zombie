require "./helpers"
{ vows: vows, assert: assert, zombie: zombie, brains: brains } = require("vows")
jsdom = require("jsdom")

brains.get "/jquery", (req, res)-> res.send """
  <html>
    <head>
      <title>jQuery</title>
      <script src="/jquery.js"></script>
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
          $.post("/echo", {"foo": "bar"}, function(response) {
            $("#response").text(response);
          });

          return false;
        });
      });
    </script>
  </html>
  """

brains.post "/echo", (req, res)->
  lines = for key, value of req.body
    key + "=" + value

  res.send lines.join("\n")

vows.describe("Compatibility with JavaScript libraries").addBatch(
  "jQuery":
    zombie.wants "http://localhost:3003/jquery"
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
