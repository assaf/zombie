const bodyParser    = require('body-parser');
const cookieParser  = require('cookie-parser');
const express       = require('express');
const File          = require('fs');
const Multiparty    = require('multiparty')
const morgan        = require('morgan');
const Path          = require('path');


// An Express server we use to test the browser.
const server = express();

server.use(bodyParser.urlencoded({ extended: true }));
server.use(bodyParser.json());
server.use(bodyParser.text());
server.use(cookieParser());
server.use(function(req, res, next) {
  if (req.method === 'POST' && req.headers['content-type'].split(';')[0] === 'multipart/form-data') {

    const form = new Multiparty.Form();
    form.parse(req, function(error, fields, files) {
      req.files = files;
      next(error);
    });

  } else
    next();
});

// Even tests need good logs
if (process.env.DEBUG)
  server.use(morgan());


// Use this for static responses.  First argument is the path, the remaining
// arguments are used with res.send, so can be static HTML, status code, etc.
server.static = function(path, output, options) {
  const status = (options && options.status) || 200;
  server.get(path, function(req, res) {
    res.status(status).send(output);
  });
};

// Use this for redirect responses.  First argument is the path, the remaining
// arguments are used with res.redirct, so can be URL and status code.
server.redirect = function(path, location, options) {
  const status = (options && options.status) || 302;
  server.get(path, function(req, res) {
    res.redirect(status, location);
  });
};


server.static('/', `
  <html>
    <head>
      <title>Tap, Tap</title>
    </head>
    <body>
    </body>
  </html>`);

// Prevent sammy from polluting the output. Comment this if you need its
// messages for debugging.
server.get('/sammy.js', function(req, res) {
  File.readFile(__dirname + '/../scripts/sammy.js', function(error, data) {
    //    unless process.env.DEBUG
    //  data = data + ";window.Sammy.log = function() {}"
    res.send(data);
  });
});

server.get('/jquery.js', function(req, res) {
  res.redirect('/jquery-2.0.3.js');
});
server.get('/jquery-:version.js', function(req, res) {
  const version = req.params.version;
  File.readFile(__dirname + '/../scripts/jquery-' + version + '.js', function(error, data) {
    res.send(data);
  });
});
server.get('/scripts/require.js', function(req, res) {
  const file = Path.resolve(require.resolve('requirejs'), '../../require.js');
  File.readFile(file, function(error, data) {
    res.send(data);
  });
});
server.get('/scripts/*', function(req, res) {
  File.readFile(__dirname + '/../scripts/' + req.params, function(error, data) {
    res.send(data);
  });
});


const serverPromise = new Promise(function(resolve) {
  server.listen(3003, function() {
    resolve();
  });
});
server.ready = function(callback) {
  if (callback)
    serverPromise.then(callback);
  else
    return serverPromise;
};


module.exports = server;
