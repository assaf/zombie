# See http://www.w3.org/TR/DOM-Level-3-XPath/
vm = process.binding("evals")
fs = require("fs")
core = require("jsdom").dom.level3.core

# Cache the XPath engine so we only load it if we need it and only load
# it once.
engine = null
xpath = ->
  unless engine
    engine = vm.Script.createContext()
    engine.navigator = { appVersion: "Zombie.js" }
    new vm.Script(fs.readFileSync(__dirname + "/../../dep/util.js")).runInContext engine
    new vm.Script(fs.readFileSync(__dirname + "/../../dep/xmltoken.js")).runInContext engine
    new vm.Script(fs.readFileSync(__dirname + "/../../dep/xpath.js")).runInContext engine
  return engine

core.HTMLDocument.prototype.evaluate = (expr, node, nsResolver, type, result)->
  engine = xpath()
  context = new engine.ExprContext(node || this)
  context.setCaseInsensitive true
  engine.xpathParse(expr).evaluate(context)
