var coffee = require("coffee-script");
var File = require("fs");
require.extensions[".coffee"] = function (module, filename) {
  var source = coffee.compile(File.readFileSync(filename, "utf8"));
  return module._compile(source, filename);
};
var zombie = require("./zombie.coffee");
for (var n in zombie)
  exports[n] = zombie[n];
