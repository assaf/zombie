require.paths.push(__dirname)
vows = require("vows", "assert")
assert = require("assert")
{ server: server, visit: visit } = require("helpers")


server.get "/boo", (req, res)->
  res.send "<html><title>Eeek!</title></html>"


vows.describe("EventLoop").addBatch({

}).export(module);
