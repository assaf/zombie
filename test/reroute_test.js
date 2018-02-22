const assert  = require('assert');
const brains  = require('./helpers/brains');
const Browser = require('../src');
const Net     = require('net');
const Replay  = require('replay');
const request = require('request');


describe('Rerouting', function() {
  let response;

  before(function() {
    Browser.localhost('foobar.com:3005', 3003);
  });

  before(function() {
    return brains.ready();
  });

  it('should connect to localhost', function() {
    const socket = Net.createConnection({ host: 'foobar.com', port: 3005, family: 4 });
    socket.destroy();
  });
});
