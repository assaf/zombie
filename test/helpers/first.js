const traceur = require('traceur');


// All JS files, excluding node_modules, are transpiled using Traceur.
traceur.require.makeDefault(function(filename) {
  return !(/\/(node_modules|test\/scripts)\//.test(filename));
}, {
  // for traceur >= 0.0.51
  experimental: true
});

// for traceur < 0.0.50, not work in the new version.
traceur.options.experimental = true;