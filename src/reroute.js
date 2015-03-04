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
// key   - Source host name or wildcard (e.g. "example.com", "*.example.com")
// value - Object that maps source port to target port
const routing = {};

// Flip this from enable() so we only inject our code into Socket.connect once.
let   enabled = false;


// Reroute any network connections from source (hostname and optional port) to
// target (port).
module.exports = function route(source, target) {
  assert(source, 'Expected source address of the form "host:port" or just "host"');
  const sourceHost = source.split(':')[0];
  const sourcePort = source.split(':')[1] || 80;
  if (!routing[sourceHost])
    routing[sourceHost] = { };
  if (!routing[sourceHost][sourcePort])
    routing[sourceHost][sourcePort] = target;
  assert(routing[sourceHost][sourcePort] === target,
         `Already have routing from ${source} to ${routing[sourceHost][sourcePort]}`);
  
  // Enable Socket.connect routing
  enable();
};


// If there's a route for host/port, returns destination port number.
//
// Called recursively to handle wildcards.  Starting with the host
// www.example.com, it will attempt to match routes from most to least specific:
//
//   www.example.com
// *.www.example.com
//     *.example.com
//             *.com
function find(hostname, port) {
  const route = routing[hostname];
  if (route) {
    return route[port];
  } else {
    // This will first expand www.hostname.com to *.www.hostname.com,
    // then contract it to *.hostname.com, *.com and finally *.
    const wildcard = hostname.replace(/^(\*\.[^.]+(\.|$))?/, '*.');
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
      const port = find(options.host, options.port);
      if (port) {
        options = Object.assign({}, options, { host: 'localhost', port });
        return connect.call(this, options, callback);
      }
    }
    return connect.apply(this, arguments);
  };
}

