# Constructor for a new Browser. Takes no arguments.
exports.Browser = require("zombie/browser").Browser
# Creates and returns a new Browser. Opens a window to the specified URL and
# calls the callback with null, browser if loaded, error otherwise. 
exports.browse = (url, callback)->
  browser = new exports.Browser
  browser.open url, callback
  browser
