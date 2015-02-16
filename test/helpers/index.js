// We switch this directory to instrumented code when running code coverage
// report
const Replay    = require('replay');
const Browser   = require('../../src');


Browser.default.silent = false;
// Tests visit example.com, server is localhost port 3003
Browser.localhost('*.example.com', 3003);


// Redirect all HTTP requests to localhost
Replay.fixtures = __dirname + '/../replay';
Replay.networkAccess = true;
Replay.localhost('*.example.com');


module.exports = {
  assert:   require('assert'),
  brains:   require('./brains'),
  Browser:  Browser
};
