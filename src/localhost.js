const reroute = require('./reroute');


let firstHostname = null;

function localhost(hostname, port = 3000) {
  if (hostname) {
    reroute(`${hostname}:80`, `localhost:${port}`);
    firstHostname = hostname;
  }
  return firstHostname;
}

module.exports = { localhost };
