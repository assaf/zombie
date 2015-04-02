// Enable ES6/7 before loading the Browser
require('babel/register')();


const Bluebird  = require('bluebird');
const Browser   = require('../../src');
const Path      = require('path');
const Replay    = require('replay');


// Tests visit example.com, server is localhost port 3003
Browser.localhost('*.example.com', 3003);

// Redirect all HTTP requests to localhost
Replay.fixtures = Path.join(__dirname, '/../replay');
Replay.networkAccess = true;
Replay.localhost('*.example.com');

// Long stack traces when running this test suite
Bluebird.longStackTraces();

