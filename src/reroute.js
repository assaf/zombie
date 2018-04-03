// Domain routing and port forwarding
//
// Used for mapping hosts and domains to localhost, so you can open TCP
// connections with friendly hostnames to test against the local server.
//
// Can also map any source port to any destination port, so you can use port 80
// to access localhost server running on unprivileged port.


const assert  = require('assert');
const Net     = require('net');


// Routing table.
//
// key   - Source host name or wildcard (e.g. "example.com", "*.example.com")
// value - Object that maps source port to target port
const routing = new Map();

// Flip this from enableRerouting() so we only inject our code into
// Socket.connect once.
let   enabled = false;


// If there's a route for host/port, returns destination port number.
//
// Called recursively to handle wildcards.  Starting with the host
// www.example.com, it will attempt to match routes from most to least specific:
//
//   www.example.com
// *.www.example.com
//     *.example.com
//             *.com
function findTargetPort(hostname, port) {
  if (!hostname)
    return null;

  const route = routing.get(hostname);
  if (route)
    return route[port];

  // This will first expand www.hostname.com to *.www.hostname.com,
  // then contract it to *.hostname.com, *.com and finally *.
  const wildcard = hostname.replace(/^(\*\.[^.]+(\.|$))?/, '*.');
  if (wildcard !== '*.')
    return findTargetPort(wildcard, port);
}


// Called once to hack Socket.connect
function enableRerouting() {
  if (enabled)
    return;
  enabled = true;

  const connect = Net.Socket.prototype.connect;
  Net.Socket.prototype.connect = function(options, callback) {
    const hasNormalizedArgs = Object.getOwnPropertySymbols && Object.getOwnPropertySymbols(options).length > 0;
    const isNode8           = Array.isArray(options) && hasNormalizedArgs;
    if (isNode8) {
      const reroutedOptions = rerouteOptions(options[0]);
      callback              = options[1];
      return connect.call(this, reroutedOptions, callback);
    } else if (typeof options === 'object') {
      const reroutedOptions = rerouteOptions(options);
      return connect.call(this, reroutedOptions, callback);
    } else
      return connect.apply(this, arguments);
  };
}


function rerouteOptions(options) {
  const port = findTargetPort(options.host, options.port);
  if (port)
    return Object.assign({}, options, { host: 'localhost', port });
  else
    return options;
}


// source - Hostname or host:port (default to port 80)
// target - Target port number
module.exports = function addRoute(source, target) {
  assert(source, 'Expected source address of the form "host:port" or just "host"');
  const sourceHost    = source.split(':')[0];
  const sourcePort    = source.split(':')[1] || 80;
  const route         = routing.get(sourceHost) || {};
  routing.set(sourceHost, route);
  if (!route[sourcePort])
    route[sourcePort] = target;
  assert(route[sourcePort] === target,
         `Already have routing from ${source} to ${route[sourcePort]}`);

  // Enable Socket.connect routing
  enableRerouting();
};
