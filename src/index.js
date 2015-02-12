const Assert    = require('./assert');
const Resources = require('./resources');
const Browser   = require('./browser');


Browser.Assert    = Assert;
Browser.Resources = Resources;


// ### zombie.visit(url, callback)
// ### zombie.visit(url, options? callback)
//
// Creates a new Browser, opens window to the URL and calls the callback when
// done processing all events.
//
// * url -- URL of page to open
// * callback -- Called with error, browser
Browser.visit = function(url, options, callback) {
  if (arguments.length === 2 && typeof(options) === 'function')
    [options, callback] = [null, options];
  const browser = Browser.create(options);
  if (callback)
    browser.visit(url, (error)=> callback(error, browser));
  else
    return browser.visit(url).then(()=> browser);
};


// ### listen port, callback
// ### listen socket, callback
// ### listen callback
//
// Ask Zombie to listen on the specified port for requests.  The default
// port is 8091, or you can specify a socket name.  The callback is
// invoked once Zombie is ready to accept new connections.
Browser.listen = function(port, callback) {
  require('./zombie/protocol').listen(port, callback);
};


// Export the globals from browser.coffee
module.exports = Browser;

