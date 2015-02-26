// Domain routing and port forwarding
//
// You can map all network connections from one host to another.  You can also
// map all network connections from one host/port to another host/port.
// Wildcards allow routing multiple hostnames and even entire TLD.
//
// For example: 
//
//   // Any connection to .test TLD handled by localhost
//   reroute('*.test', 'localhost');
//   // HTTP/S connections to example.test handled by localhost:3000/1
//   reroute('example.test:80', 'localhost:3000');
//   reroute('example.test:443', 'localhost:3001');


const assert  = require('assert');
const Net     = require('net');


// Routing table.
//
// key   - Soruce host name or wildcard (e.g. "example.com", "*.example.com")
// value - Target host name and port mapping, see blow
//
// The target object has:
//
// host   - Target host name
// ports  - Object mapping source port number to target port number
const routing = {};

// Flip this from enable() so we only inject our code into Socket.connect once.
let   enabled = false;


// Reroute any network connections from source to target.
//
// If source is a hostname, target must also be a hostname.  Connections will be
// routed using the same port.
//
// If source is host:port, target must also be host:port.  Connections will be
// routed to different host and port.
//
// You can call multiple times with any combination of the above.  In additionl,
// source host can start with a wildcard.  For example, '*.example.com' will
// match 'example.com' and 'www.example.com'.
module.exports = function route(source, target) {
  assert(source, 'Expected source address of the form "host:port" or just "host"');
  const sourceHost = source.split(':')[0];
  const sourcePort = +source.split(':')[1];
  if (sourcePort) {

    // Route from one host:port combination to another host:port
    const targetHost  = target.split(':')[0];
    const targetPort  = +target.split(':')[1];
    assert(targetHost && targetPort, 'Expected target address of the form "host:port", target port required');
    if (!routing[sourceHost]) {
      routing[sourceHost] = {
        host:   targetHost,
        ports:  {} 
      };
    }
    assert(routing[sourceHost].host === targetHost,
           'Already have routing from ' + source + ' to ' + routing[sourceHost].host);
    if (!routing[sourceHost].ports[sourcePort])
      routing[sourceHost].ports[sourcePort] = targetPort;
    assert(routing[sourceHost].ports[sourcePort] === targetPort,
           'Already have routing from ' + source +' to ' + routing[sourceHost].host + ':' + routing[sourceHost].ports[sourcePort]);
  
  } else {

    // Route from one host to another (don't change ports)
    assert(target.indexOf('.') < 0, 'Expected target address of the form "host", no port allowed');
    if (!routing[sourceHost]) {
      routing[sourceHost] = {
        host:   target,
        ports:  {} 
      };
    }
    assert(routing[sourceHost].host === target,
           'Already have routing from ' + source + ' to ' + routing[sourceHost].host);

  
  }
  // Enable Socket.connect routing
  enable();
};


// If there's a route for host/port, return object with host/port properties.
//
// Called recursively to handle wildcards.  Starting with the host
// www.example.com, it will attempt to match routes from most to least specific:
//
//   www.example.com
// *.www.example.com
//     *.example.com
//             *.com
function find(host, port) {
  const route = routing[host];
  if (route) {
    return {
      host: route.host,
      port: route.ports[port] || port
    };
  } else {
    // This will first expand www.hostname.com to *.www.hostname.com,
    // then contract it to *.hostname.com, *.com and finally *.
    const wildcard = host.replace(/^(\*\.[^.]+(\.|$))?/, '*.');
    if (wildcard !== '*.')
      return find(wildcard, port);
  }
}


// Called once to hack Socket.connect
function enable() {
  if (enabled)
    return;
  enabled = true;

  const connect = Net.Socket.prototype.connect;
  Net.Socket.prototype.connect = function(options, callback) {
    if (typeof(options) === 'object') {
      const route = find(options.host, options.port);
      if (route) {
        options = Object.assign({}, options, route);
        return connect.call(this, options, callback);
      }
    }
    return connect.apply(this, arguments);
  };
}

