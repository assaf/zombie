{ assert, brains, Browser } = require("./helpers")


describe "Google map", ->

  browser = new Browser()

  before (done)->
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

    brains.ready done

  before (done)->
    browser.visit "http://localhost:3003/browser/map", done

  it "should load map", ->
    assert browser.window.map
  it "should set bounds", ->
    bounds = browser.window.map.getBounds()
    assert bounds, "No map bounds yet"
    assert.equal bounds.toString(), "((-34.62332513513795, 150.369341796875), (-34.17006113241608, 150.918658203125))"

