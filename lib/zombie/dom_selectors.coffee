# Support for CSS selectors (querySelector and querySelectorAll)


Path          = require("path")
HTML          = require("jsdom").dom.level3.html
createSizzle  = require(Path.resolve(require.resolve("jsdom"), "../jsdom/selectors/sizzle"))


# Implement documentElement.contains
# e.g., if(document.body.contains(el)) { ... }
# See https://developer.mozilla.org/en-US/docs/DOM/Node.contains
HTML.Node.prototype.contains = (otherNode) ->
  # DDOPSON-2012-08-16 -- This implementation is stolen from Sizzle's implementation of 'contains' (around line 1402).
  # We actually can't call Sizzle.contains directly: 
  # * Because we define Node.contains, Sizzle will configure it's own "contains" method to call us. (it thinks we are a native browser implementation of "contains")
  # * Thus, if we called Sizzle.contains, it would form an infinite loop.  Instead we use Sizzle's fallback implementation of "contains" based on "compareDocumentPosition".
  return !!(this.compareDocumentPosition(otherNode) & 16)


# True if element is child of context node or any of its children.
descendantOf = (element, context)->
  parent = element.parentNode
  if parent
    return parent == context || descendantOf(parent, context)
  else
    return false

# Here comes the tricky part:
#   getDocumentById("foo").querySelectorAll("#foo div")
# should magically find the div descendant(s) of #foo, although
# querySelectorAll can never "see" itself.
descendants = (element, selector)->
  document = element.ownerDocument
  document._sizzle ||= createSizzle(document)
  unless element.parentNode
    parent = element.ownerDocument.createElement("div")
    parent.appendChild(element)
    element = parent
  return document._sizzle(selector, element.parentNode || element)
    .filter((node) -> descendantOf(node, element))

# querySelector(All) for HTML document
HTML.HTMLDocument.prototype.querySelector = (selector)->
  @_sizzle ||= createSizzle(this)
  return @_sizzle(selector, this)[0]
HTML.HTMLDocument.prototype.querySelectorAll = (selector)->
  @_sizzle ||= createSizzle(this)
  return new HTML.NodeList(@_sizzle(selector, this))

# querySelector(All) for HTML element
HTML.Element.prototype.querySelector = (selector)->
  return descendants(this, selector)[0]
HTML.Element.prototype.querySelectorAll = (selector)->
  return new HTML.NodeList(descendants(this, selector))
