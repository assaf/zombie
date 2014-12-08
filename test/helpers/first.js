const Bluebird  = require('bluebird');
const Traceur   = require('traceur');


// All JS files, excluding node_modules, are transpiled using Traceur.
Traceur.require.makeDefault(function(filename) {
  return !(/\/(node_modules|test\/scripts)\//.test(filename));
}, {
  asyncFunctions: true,
  experimental: true,
  debug: true
});


// Long stack traces when running this test suite
Bluebird.longStackTraces();
