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
    </body>

    <script>
      $(function() {

        $("select").bind("change", function() {
          $("#option").text(this.value);
        });

      });
    </script>
  </html>
  """

vows.describe("Compatibility with JavaScript libraries").addBatch(
  "jQuery":
    zombie.wants "http://localhost:3003/jquery"
      "selecting an option in a select element":
        topic: (browser)->
          browser.select "select", "1"
          @callback null, browser
        "should fire the change event": (browser)-> assert.equal browser.text("#option"), "1"


).export(module)
