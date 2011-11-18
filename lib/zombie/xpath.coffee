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


# compareDocumentPosition
# -----------------------

# compareDocumentPosition is buggy on JS DOM. When it finds a common ancestor,
# it tries to find the compared nodes as ancestor children but this is not
# necessarily true. The proper behavior is to check the first child for that
# ancestor that is a parent to each node.


# Compare Document Position
DOCUMENT_POSITION_DISCONNECTED = html.Node.prototype.DOCUMENT_POSITION_DISCONNECTED = 0x01
DOCUMENT_POSITION_PRECEDING    = html.Node.prototype.DOCUMENT_POSITION_PRECEDING    = 0x02
DOCUMENT_POSITION_FOLLOWING    = html.Node.prototype.DOCUMENT_POSITION_FOLLOWING    = 0x04
DOCUMENT_POSITION_CONTAINS     = html.Node.prototype.DOCUMENT_POSITION_CONTAINS     = 0x08
DOCUMENT_POSITION_CONTAINED_BY = html.Node.prototype.DOCUMENT_POSITION_CONTAINED_BY = 0x10
DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC = html.Node.prototype.DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC = 0x20

html.Node.prototype.compareDocumentPosition = (otherNode)->
  if !(otherNode instanceof html.Node)
    throw Error("Comparing position against non-Node values is not allowed")

  if this.nodeType == this.DOCUMENT_NODE
    thisOwner = this
  else
    thisOwner = this.ownerDocument

  if otherNode.nodeType == this.DOCUMENT_NODE
    otherOwner = otherNode
  else
    otherOwner = otherNode.ownerDocument

  if this == otherNode then return 0
  if this == otherNode.ownerDocument then return DOCUMENT_POSITION_FOLLOWING + DOCUMENT_POSITION_CONTAINED_BY
  if this.ownerDocument == otherNode then return DOCUMENT_POSITION_PRECEDING + DOCUMENT_POSITION_CONTAINS
  if thisOwner != otherOwner then return DOCUMENT_POSITION_DISCONNECTED

  # Text nodes for attributes does not have a _parentNode. So we need to find them as attribute child.
  if this.nodeType == this.ATTRIBUTE_NODE && this._childNodes && this._childNodes.indexOf(otherNode) != -1
    return DOCUMENT_POSITION_FOLLOWING + DOCUMENT_POSITION_CONTAINED_BY

  if otherNode.nodeType == this.ATTRIBUTE_NODE && otherNode._childNodes && otherNode._childNodes.indexOf(this) != -1
    return DOCUMENT_POSITION_PRECEDING + DOCUMENT_POSITION_CONTAINS

  point = this
  parents = [ ]
  previous = null
  while point
    if point == otherNode
      return DOCUMENT_POSITION_PRECEDING + DOCUMENT_POSITION_CONTAINS
    parents.push point
    point = point._parentNode
  point = otherNode
  previous = null
  while point
    if point == this
      return DOCUMENT_POSITION_FOLLOWING + DOCUMENT_POSITION_CONTAINED_BY
    location_index = parents.indexOf(point)
    if location_index != -1
     smallest_common_ancestor = parents[ location_index ]
     this_index = smallest_common_ancestor._childNodes.indexOf( parents[location_index - 1] )
     other_index = smallest_common_ancestor._childNodes.indexOf( previous )
     if this_index > other_index
       return DOCUMENT_POSITION_PRECEDING
     else
       return DOCUMENT_POSITION_FOLLOWING
    previous = point
    point = point._parentNode
  return DOCUMENT_POSITION_DISCONNECTED
