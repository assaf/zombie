// Enable ES6/7 before loading the Browser
const babel     = require('babel/register');
babel({
  experimental: true,
  loose:        'all'
});


const Bluebird  = require('bluebird');
const Browser   = require('../../src');
const Replay    = require('replay');


// Tests visit example.com, server is localhost port 3003
Browser.localhost('*.example.com', 3003);
Browser.default.site = 'example.com';

// Redirect all HTTP requests to localhost
Replay.fixtures = __dirname + '/../replay';
Replay.networkAccess = true;
Replay.localhost('*.example.com');

// Long stack traces when running this test suite
Bluebird.longStackTraces();

