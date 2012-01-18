{ Vows, assert, brains, Browser } = require("./helpers")


Vows.describe("Google map").addBatch

  "display":
    topic: ->
      brains.get "/browser/map", (req, res)->
        res.send """
        <html>
          <head>
            <script type="text/javascript" src="//maps.googleapis.com/maps/api/js?v=3&sensor=false&callback=initialize"></script>
            <script type="text/javascript">
              window.initialize = function() {
                window.map = new google.maps.Map(document.getElementById("map"), {
                  center: new google.maps.LatLng(-34.397, 150.644),
                  zoom: 8,
                  mapTypeId: google.maps.MapTypeId.ROADMAP
                });
              }
            </script>
          </head>
          <body>
            <div id="map"></div>
          </body>
        </html>
        """

      brains.ready =>
        browser = new Browser
        browser.visit "http://localhost:3003/browser/map", =>
          browser.wait @callback
    "should load map": (browser)->
      assert.ok browser.window.map
    "should set bounds": (browser)->
      bounds = browser.window.map.getBounds()
      assert.ok bounds, "No map bounds yet"
      assert.equal bounds.toString(), "((-34.62332513513795, 150.369341796875), (-34.17006113241608, 150.918658203125))"


.export(module)
