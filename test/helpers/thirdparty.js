// Creates an Express server for testing 3rd party sites against thirdparty.test. 
// Exports a method that returns a promise that resolves to a live Express server.

const Browser = require('../../src');
const debug   = require('debug')('server');
const Express = require('express');
const morgan  = require('morgan');
const Replay  = require('replay');


// Need sparate port from the test server (see index.js).
const PORT      = 3005;
const HOSTNAME  = 'thirdparty.test';


// This will map any HTTP request to theweb.test to the right port.
Browser.localhost(HOSTNAME, PORT);
Replay.localhost(HOSTNAME);


const server = new Express();

// Even tests need good logs
if (debug.enabled)
  server.use(morgan('dev', { stream: { write: debug } }));

// ... and error reporting
server.use(function(error, req, res, next) {
  console.error(error);
  next(error);
});


// Promise that resolves to a running server.
const serverPromise = new Promise(function(resolve, reject) {
  server.listen(PORT, function(error) {
    if (error)
      reject(error);
    else
      resolve(server);
  });
});

module.exports = function() {
  return serverPromise;
};

