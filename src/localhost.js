const dns   = require('./dns_mask');
const ports = require('./port_map');


function localhost(hostname, port = 3000) {
  if (hostname) {
    dns.localhost(hostname);
    ports.map(hostname, port);
  }
  return ports.names[0].replace(/^\*\./, '');
}

module.exports = { localhost, dns, ports };
