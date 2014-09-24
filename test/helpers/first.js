const traceur = require('traceur');


// All JS files, excluding node_modules, are transpiled using Traceur.
traceur.require.makeDefault(function(filename) {
  return !(/\/(node_modules|test\/scripts)\//.test(filename));
}, {
  experimental: true
});
