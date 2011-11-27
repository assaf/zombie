var coffee = require("coffee-script");
var File = require("fs");
if (!require.extensions[".coffee"]) {
  require.extensions[".coffee"] = function (module, filename) {
    var source = coffee.compile(File.readFileSync(filename, "utf8"));
    return module._compile(source, filename);
  };
}
var exported = require(__filename.replace(/\.js$/, "/index.coffee"));
for (var n in exported)
  exports[n] = exported[n];
