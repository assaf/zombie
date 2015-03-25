const assert  = require('assert');
const brains  = require('./helpers/brains');
const Browser = require('../src');


describe('Google map', function() {
  const browser = new Browser();

  before(function() {
    brains.static('/browser/map', `
      <html>
        <head></head>
        <body>
          <div id="map"></div>
          <script type="text/javascript">
            window.initialize = function() {
              window.map = new google.maps.Map(document.getElementById('map'), {
                center: new google.maps.LatLng(-34.397, 150.644),
                zoom: 8,
                mapTypeId: google.maps.MapTypeId.ROADMAP
              });
            }
          </script>
          <script type="text/javascript" src="//maps.googleapis.com/maps/api/js?v=3&sensor=false&callback=initialize"></script>
        </body>
      </html>`);
    return brains.ready();
  });

  before(async function() {
    browser.visit('/browser/map');
    await browser.wait({ element: '.gmnoprint' });
  });

  it('should load map', function() {
    assert(browser.window.map);
  });
  it('should set bounds', function() {
    const bounds = browser.window.map.getBounds();
    assert(bounds, 'No map bounds yet');
    assert(bounds.getNorthEast());
    assert(bounds.getSouthWest());
  });

  after(function() {
    browser.destroy();
  });

});
