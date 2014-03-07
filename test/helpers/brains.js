const express = require('express');
const File    = require('fs');
const Path    = require('path');


// An Express server we use to test the browser.
const brains = express();
brains.use(express.bodyParser());
brains.use(express.cookieParser());


// Use this for static responses.  First argument is the path, the remaining
// arguments are used with res.send, so can be static HTML, status code, etc.
brains.static = function(path, ...output) {
  brains.get(path, function(req, res) {
    res.send(...output);
  });
}

// Use this for redirect responses.  First argument is the path, the remaining
// arguments are used with res.redirct, so can be URL and status code.
brains.redirect = function(path, ...location) {
  brains.get(path, function(req, res) {
    res.redirect(...location);
  });
}


brains.static('/', "\
  <html>\
    <head>\
      <title>Tap, Tap</title>\
    </head>\
    <body>\
    </body>\
  </html>\
");

// Prevent sammy from polluting the output. Comment this if you need its
// messages for debugging.
brains.get('/sammy.js', function(req, res) {
  File.readFile(__dirname + '/../scripts/sammy.js', function(error, data) {
    //    unless process.env.DEBUG
    //  data = data + ";window.Sammy.log = function() {}"
    res.send(data);
  });
});

brains.get('/jquery.js', function(req, res) {
  res.redirect('/jquery-2.0.3.js');
});
brains.get('/jquery-:version.js', function(req, res) {
  let version = req.params.version
  File.readFile(__dirname + '/../scripts/jquery-' + version + '.js', function(error, data) {
    res.send(data);
  });
});
brains.get('/scripts/require.js', function(req, res) {
  let file = Path.resolve(require.resolve('requirejs'), '../../require.js');
  File.readFile(file, function(error, data) {
    res.send(data);
  });
});
brains.get('/scripts/*', function(req, res) {
  File.readFile(__dirname + '/../scripts/' + req.params, function(error, data) {
    res.send(data);
  });
});


var serverPromise = new Promise(function(resolve, reject) {
  brains.listen(3003, function() {
    resolve();
  });
});
brains.ready = function(callback) {
  if (callback)
    serverPromise.then(callback);
  else
    return serverPromise;
}


module.exports = brains
