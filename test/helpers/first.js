const Bluebird  = require('bluebird');
const babel     = require('babel/register');


babel({
  experimental: true,
  loose:        'all'
});

// Long stack traces when running this test suite
Bluebird.longStackTraces();
