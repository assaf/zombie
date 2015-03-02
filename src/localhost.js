const reroute = require('./reroute');


let firstHostname = null;

function localhost(hostname, target_port = 3000, target_hostname = 'localhost') {
  if (hostname) {
    reroute(`${hostname}:80`, `${target_hostname}:${target_port}`);
    firstHostname = hostname;
  }
  return firstHostname;
}

module.exports = { localhost };
