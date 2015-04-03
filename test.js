const Util = require('util');

const a = [];
console.log([].concat(a).length);     // => 0
console.log([].slice.call(a).length); // => 0

const Arrayish = function() {
  Array.call(this);
}
Util.inherits(Arrayish, Array);
const b = new Arrayish();
console.log([].concat(b).length);     // => 1
console.log([].slice.call(b).length); // => 0

