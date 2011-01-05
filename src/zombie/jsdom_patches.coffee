# Fix things that JSDOM doesn't do quite right.
core = require("jsdom").dom.level3.core
URL = require("url")
http = require("http")
html5 = require("html5").HTML5


# Links/Resources
# ---------------

# Default behavior for clicking on links: navigate to new URL is specified.
core.HTMLAnchorElement.prototype._eventDefaults = 
  click: (event)->
    anchor = event.target
    anchor.ownerDocument.parentWindow.location = anchor.href if anchor.href

# Fix resource loading to keep track of in-progress requests. Need this to wait
# for all resources (mainly JavaScript) to complete loading before terminating
# browser.wait.
core.resourceLoader.load = (element, href, callback)->
  document = element.ownerDocument
  window = document.parentWindow
  ownerImplementation = document.implementation
  if ownerImplementation.hasFeature('FetchExternalResources', element.tagName.toLowerCase())
    window.request { url: href, method: "GET", headers: {} }, (done)=>
      url = URL.parse(@resolve(document, href))
      loaded = (data, filename)->
        done null, { status: 200, headers: {}, body: data.slice(0,100) }
        callback.call this, data, filename
      if url.hostname
        @download url, @enqueue(element, loaded, url.pathname)
      else
        file = @resolve(document, url.pathname)
        @readFile file, @enqueue(element, loaded, file)

# Adds redirect support when loading resources (JavaScript).
core.resourceLoader.download = (url, callback)->
  path = url.pathname + (url.search || "")
  client = http.createClient(url.port || 80, url.hostname)
  request = client.request("GET", path, "host": url.hostname)
  request.on "response", (response)->
    response.setEncoding "utf8"
    data = ""
    response.on "data", (chunk)-> data += chunk
    response.on "end", ()->
      switch response.statusCode
        when 301, 302, 303, 307
          redirect = URL.resolve(url, response.headers["location"])
          download redirect, callback
        else
          callback null, data
  # TODO: add to JSDOM
  request.on "error", (error)-> callback error
  request.end()


# Scripts
# -------

core.languageProcessors =
  javascript: (element, code, filename)->
    document = element.ownerDocument
    window = document.parentWindow
    window.browser.log -> "Running script from #{filename}" if filename
    try
      window.browser.evaluate code, filename
    catch error
      event = document.createEvent("HTMLEvents")
      event.initEvent "error", true, false
      event.error = error
      window.dispatchEvent event

# DOMCharacterDataModified event fired when text is added to a
# TextNode.  This is a crappy implementation, a good one would old and
# new values in the event.
core.CharacterData.prototype.__defineSetter__ "_nodeValue", (newValue)->
  oldValue = @_text || ""
  @_text = newValue
  if @ownerDocument && @parentNode
    ev = @ownerDocument.createEvent("MutationEvents")
    ev.initMutationEvent("DOMCharacterDataModified", true, false, this, oldValue, newValue, null, null)
    @dispatchEvent ev
core.CharacterData.prototype.__defineGetter__ "_nodeValue", -> @_text

# Add support for DOMCharacterDataModified, so we can execute a script
# when its text contents is changed.  Safari and Firefox support that.
core.Document.prototype._elementBuilders["script"] = (doc, s)->
  script = new core.HTMLScriptElement(doc, s)
  script.sourceLocation ||= { line: 0, col: 0 }
  if doc.implementation.hasFeature("ProcessExternalResources", "script")
    script.addEventListener "DOMCharacterDataModified", (event)->
      code = event.target.nodeValue
      if code.trim().length > 0
        filename = @ownerDocument.URL
        @ownerDocument.parentWindow.perform (done)=>
          loaded = (code, filename)=>
            core.languageProcessors[@language](this, code, filename) if code == @text
            done()
          core.resourceLoader.enqueue(this, loaded, filename)(null, code)
  return script


# Queue
# -----

# Fixes two bugs in ResourceQueue:
# - Queue doesn't process items that have empty data (this.data == "")
# - Should change tail to null if current item is tail, but should not
#   change tail to next, since item.next may be few items before tail
core.HTMLDocument.prototype.fixQueue = ->
  @_queue.push = (callback)->
    q = this
    item =
      prev: q.tail
      check: ()->
        if !q.paused && (this.data != undefined || this.err) && !this.prev # fix #1
          callback(this.err, this.data)
          if q.tail == this # fix #2
            q.tail = null
          if this.next
            this.next.prev = null
            this.next.check()
    if q.tail
      q.tail.next = item
    q.tail = item
    return (err, data)->
      item.err = err
      item.data = data
      item.check()

# compareDocumentPosition
# -----------------------

# compareDocumentPosition is buggy on JS DOM. When it finds a common ancestor,
# it tries to find the compared nodes as ancestor children but this is not
# necessarily true. The proper behavior is to check the first child for that
# ancestor that is a parent to each node.

`
// Compare Document Position
var DOCUMENT_POSITION_DISCONNECTED = core.Node.prototype.DOCUMENT_POSITION_DISCONNECTED = 0x01;
var DOCUMENT_POSITION_PRECEDING    = core.Node.prototype.DOCUMENT_POSITION_PRECEDING    = 0x02;
var DOCUMENT_POSITION_FOLLOWING    = core.Node.prototype.DOCUMENT_POSITION_FOLLOWING    = 0x04;
var DOCUMENT_POSITION_CONTAINS     = core.Node.prototype.DOCUMENT_POSITION_CONTAINS     = 0x08;
var DOCUMENT_POSITION_CONTAINED_BY = core.Node.prototype.DOCUMENT_POSITION_CONTAINED_BY = 0x10;
var DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC = core.Node.prototype.DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC = 0x20;

core.Node.prototype.compareDocumentPosition = function compareDocumentPosition( otherNode ) {
  if( !(otherNode instanceof core.Node) ) {
    throw Error("Comparing position against non-Node values is not allowed")
  }
  var thisOwner, otherOwner;

  if( this.nodeType === this.DOCUMENT_NODE)
    thisOwner = this
  else
    thisOwner = this.ownerDocument

  if( otherNode.nodeType === this.DOCUMENT_NODE)
    otherOwner = otherNode
  else
    otherOwner = otherNode.ownerDocument

  if( this === otherNode ) return 0
  if( this === otherNode.ownerDocument ) return DOCUMENT_POSITION_FOLLOWING + DOCUMENT_POSITION_CONTAINED_BY
  if( this.ownerDocument === otherNode ) return DOCUMENT_POSITION_PRECEDING + DOCUMENT_POSITION_CONTAINS
  if( thisOwner !== otherOwner ) return DOCUMENT_POSITION_DISCONNECTED

  // Text nodes for attributes does not have a _parentNode. So we need to find them as attribute child.
  if( this.nodeType === this.ATTRIBUTE_NODE && this._childNodes && this._childNodes.indexOf(otherNode) !== -1)
    return DOCUMENT_POSITION_FOLLOWING + DOCUMENT_POSITION_CONTAINED_BY

  if( otherNode.nodeType === this.ATTRIBUTE_NODE && otherNode._childNodes && otherNode._childNodes.indexOf(this) !== -1)
    return DOCUMENT_POSITION_PRECEDING + DOCUMENT_POSITION_CONTAINS

  var point = this
  var parents = [ ]
  var previous = null
  while( point ) {
    if( point == otherNode ) return DOCUMENT_POSITION_PRECEDING + DOCUMENT_POSITION_CONTAINS
    parents.push( point )
    point = point._parentNode
  }
  point = otherNode
  previous = null
  while( point ) {
    if( point == this ) return DOCUMENT_POSITION_FOLLOWING + DOCUMENT_POSITION_CONTAINED_BY
    var location_index = parents.indexOf( point )
    if( location_index !== -1) {
     var smallest_common_ancestor = parents[ location_index ]
     var this_index = smallest_common_ancestor._childNodes.indexOf( parents[location_index - 1] )
     var other_index = smallest_common_ancestor._childNodes.indexOf( previous )
     if( this_index > other_index ) {
           return DOCUMENT_POSITION_PRECEDING
     }
     else {
       return DOCUMENT_POSITION_FOLLOWING
     }
    }
    previous = point
    point = point._parentNode
  }
  return DOCUMENT_POSITION_DISCONNECTED
};
`