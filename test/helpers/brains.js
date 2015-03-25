const bodyParser    = require('body-parser');
const cookieParser  = require('cookie-parser');
const debug         = require('debug')('server');
const express       = require('express');
const File          = require('fs');
const Multiparty    = require('multiparty');
const morgan        = require('morgan');
const Path          = require('path');
const Promise       = require('bluebird');


// An Express server we use to test the browser.
const server = express();

server.use(bodyParser.urlencoded({ extended: true }));
server.use(bodyParser.json());
server.use(bodyParser.text());
server.use(cookieParser());
server.use(function(req, res, next) {
  if (req.method === 'POST' && req.headers['content-type'].search('multipart/') === 0) {

    const form = new Multiparty.Form();
    form.parse(req, function(error, fields, files) {
      req.files = files;
      next(error);
    });

  } else
    next();
});

// Even tests need good logs
if (debug.enabled)
  server.use(morgan('dev', { stream: { write: debug } }));


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

server.get('/scripts/jquery.js', function(req, res) {
  res.redirect('/scripts/jquery-2.0.3.js');
});

server.get('/scripts/require.js', function(req, res) {
  const file    = Path.resolve('node_modules/requirejs/require.js');
  const script  = File.readFileSync(file);
  res.send(script);
});

server.get('/scripts/*', function(req, res) {
  const script = File.readFileSync(Path.join(__dirname, '/../scripts/', req.params[0]));
  res.send(script);
});


const serverPromise = new Promise(function(resolve, reject) {
  server.listen(3003, resolve);
  server.on('error', reject);
});

server.ready = function(callback) {
  if (callback)
    serverPromise.done(callback);
  else
    return serverPromise;
};


module.exports = server;
