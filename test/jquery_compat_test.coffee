{ assert, brains, Browser } = require("./helpers")


JQUERY_VERSIONS = ["1.4.4", "1.5.1", "1.6.3", "1.7.1"]


test = (version)->
  describe version, ->

    before (done)->
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

      brains.ready done


    before (done)->
      @browser = new Browser()
      @browser.visit "http://localhost:3003/compat/jquery-#{version}", done

    describe "selecting an option in a select element", ->
      before (done)->
        @browser.select "select", "1"
        done()

      it "should fire the change event", ->
        assert.equal @browser.text("#option"), "1"

    describe "jQuery.post", ->
      before (done)->
        @browser.clickLink "Post", done

      it "should perform an AJAX POST request", ->
        assert /foo=bar/.test(@browser.text("#response"))

    describe "jQuery.globalEval", ->
      it "should work as expected", ->
        @browser.evaluate("(function () {
          $.globalEval('var globalEvalWorks = true;');
        })();")
        assert.ok @browser.window.globalEvalWorks


describe "Compatibility with jQuery", ->

  for version in JQUERY_VERSIONS
    test.call this, version

