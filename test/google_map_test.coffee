{ assert, brains, Browser } = require("./helpers")


describe "Google map", ->

  browser = null
  before (done)->
    browser = Browser.create()
    brains.ready(done)

  before (done)->
    brains.get "/browser/map", (req, res)->
      res.send """
      <html>
        <head></head>
        <body>
          <div id="map"></div>
          <script type="text/javascript">
            window.initialize = function() {
              window.map = new google.maps.Map(document.getElementById("map"), {
                center: new google.maps.LatLng(-34.397, 150.644),
                zoom: 8,
                mapTypeId: google.maps.MapTypeId.ROADMAP
              });
            }
          </script>
          <script type="text/javascript" src="//maps.googleapis.com/maps/api/js?v=3&sensor=false&callback=initialize"></script>
        </body>
      </html>
      """
    brains.ready done

  before (done)->
    browser.visit("/browser/map")
    browser.wait(element: ".gmnoprint", done)

  it "should load map", ->
    assert browser.window.map
  it "should set bounds", ->
    bounds = browser.window.map.getBounds()
    assert bounds, "No map bounds yet"
    assert bounds.getNorthEast()
    assert bounds.getSouthWest()

  after ->
    browser.destroy()
