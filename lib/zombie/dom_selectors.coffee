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
isDescendantOf = (element, context)->
  parent = element.parentNode
  if parent
    return parent == context || isDescendantOf(parent, context)
  else
    return false

# Returns a query function that queries all the descendants of element base on
# the selector.  Suitable for constructing a NodeList.
queryForDescendants = (element, selector)->
  document = element.ownerDocument
  # Here comes the tricky part:
  #   getDocumentById("foo").querySelectorAll("#foo div")
  # should magically find the div descendant(s) of #foo, although
  # querySelectorAll can never "see" itself.
  unless element.parentNode
    parent = document.createElement("div")
    parent.appendChild(element)
    element = parent

  query = ->
    return document._sizzle(selector, element.parentNode || element)
      .filter((node) -> isDescendantOf(node, element))
  return query


# querySelector(All) for HTML document.
#
# This may be called before the document is loaded (e.g. form completion
# function), and Sizzle will fail if there is no document element.
HTML.HTMLDocument.prototype.querySelector = (selector)->
  document = this
  documentElement = document.documentElement
  if documentElement
    sizzle = @_sizzle ||= createSizzle(document)
    return sizzle(selector, documentElement)[0]
  else
    return null

HTML.HTMLDocument.prototype.querySelectorAll = (selector)->
  document = this
  documentElement = document.documentElement
  if documentElement
    sizzle = @_sizzle ||= createSizzle(document)
    query = ->
      return sizzle(selector, document)
    return new HTML.NodeList(documentElement, query)
  else
    return new HTML.NodeList()

# querySelector(All) for HTML element
HTML.Element.prototype.querySelector = (selector)->
  @ownerDocument._sizzle ||= createSizzle(@ownerDocument)
  return queryForDescendants(this, selector)()[0]

HTML.Element.prototype.querySelectorAll = (selector)->
  @ownerDocument._sizzle ||= createSizzle(@ownerDocument)
  return new HTML.NodeList(this, queryForDescendants(this, selector))
