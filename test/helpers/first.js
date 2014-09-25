const traceur = require('traceur');
const Bluebird = require('bluebird');

// All JS files, excluding node_modules, are transpiled using Traceur.
traceur.require.makeDefault(function(filename) {
  return !(/\/(node_modules|test\/scripts)\//.test(filename));
}, {
  experimental: true
});

// Long stack traces when running this test suite
// Bluebird.longStackTraces();
