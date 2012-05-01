# See http://www.w3.org/TR/DOM-Level-3-XPath/
vm = require("vm")
fs = require("fs")
html = require("jsdom").dom.level3.html


# Cache the XPath engine so we only load it if we need it and only load
# it once.
engine = null
xpath = ->
  unless engine
    engine = vm.Script.createContext()
    engine.navigator = { appVersion: "Zombie.js" }
    new vm.Script(fs.readFileSync(__dirname + "/../../xpath/util.js")).runInContext engine
    new vm.Script(fs.readFileSync(__dirname + "/../../xpath/xmltoken.js")).runInContext engine
    new vm.Script(fs.readFileSync(__dirname + "/../../xpath/xpath.js")).runInContext engine
  return engine


html.HTMLDocument.prototype.evaluate = (expr, node, nsResolver, type, result)->
  engine = xpath()
  context = new engine.ExprContext(node || this)
  context.setCaseInsensitive true
  result = engine.xpathParse(expr).evaluate(context)
  if result.type == 'node-set'
    result.value = result.value.sort (a,b)->
      value = a.compareDocumentPosition(b)
      if value == 2 || value == 8 || value == 10 then 1 else -1
  result

