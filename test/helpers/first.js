const Bluebird  = require('bluebird');
const to5       = require('6to5/register');


to5({
  experimental: true,
  loose:        'all'
});

// Long stack traces when running this test suite
Bluebird.longStackTraces();
