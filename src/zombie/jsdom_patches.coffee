# Fix things that JSDOM doesn't do quite right.
core = require("jsdom").dom.level3.core
URL = require("url")
http = require("http")
html5 = require("html5").HTML5


core.HTMLElement.prototype.__defineGetter__ "offsetLeft",   -> 0
core.HTMLElement.prototype.__defineGetter__ "offsetTop",    -> 0
core.HTMLElement.prototype.__defineGetter__ "offsetWidth",  -> 100
core.HTMLElement.prototype.__defineGetter__ "offsetHeight", -> 100


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
    url = URL.parse(@resolve(document, href))
    loaded = (response, filename)->
      callback.call this, response.body, URL.parse(response.url).pathname
    if url.hostname
      window.resources.get url, @enqueue(element, loaded, url.pathname)
    else
      file = @resolve(document, url.pathname)
      @readFile file, @enqueue(element, loaded, file)


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
            if core.languageProcessors[@language] && code == @text
              core.languageProcessors[@language](this, code, filename)
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
