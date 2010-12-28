# Fix things that JSDOM doesn't do quite right.
core = require("jsdom").dom.level3.core
URL = require("url")
vm = process.binding("evals")
http = require("http")
html5 = require("html5").HTML5


# Event Handling
# --------------

# Add default event behavior (click link to navigate, click button to submit
# form, etc). We start by wrapping dispatchEvent so we can forward events to
# the element's _eventDefault function (only events that did not incur
# preventDefault).
dispatchEvent = core.HTMLElement.prototype.dispatchEvent
core.HTMLElement.prototype.dispatchEvent = (event)->
  outcome = dispatchEvent.call(this, event)
  event.target._eventDefault event unless event._preventDefault
  return outcome
core.HTMLElement.prototype._eventDefault = (event)->


# Scripts
# -------

# Need to use the same context for all the scripts we load in the same document,
# otherwise simple things won't work (e.g $.xhr)
core.languageProcessors =
  javascript: (element, code, filename)->
    document = element.ownerDocument
    window = document.parentWindow
    window.browser.debug -> "Running script from #{filename}" if filename
    if window
      ctx = vm.Script.createContext(window)
      script = new vm.Script(code, filename)
      script.runInContext ctx


# Links/Resources
# ---------------

# Default behavior for clicking on links: navigate to new URL is specified.
core.HTMLAnchorElement.prototype._eventDefault = (event)->
  @ownerDocument.parentWindow.location = @href if event.type == "click" && @href

# Fix not-too-smart URL resolving in JSDOM.
core.resourceLoader.resolve = (document, path)->
  path = URL.resolve(document.URL, path)
  path.replace(/^file:/, '').replace(/^([\/]+)/, "/")
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
    response.on "data", (chunk)-> data += chunk.toString()
    response.on "end", ()->
      switch response.statusCode
        when 301, 302, 303, 307
          redirect = URL.resolve(url, response.headers["location"])
          download redirect, callback
        else
          callback null, data
  request.on "error", (error)-> callback error
  request.end()


# Scripts
# -------

# Here we deal with four JSDOM issues:
# - JSDOM assumes a SCRIPT element would have one text node, it may have
#   more, and in the second case, it has none.
# - HTML5 creates the SCRIPT element first, then adds the script
#   contents to the element.  We handle that by catching appendChild
#   with a text node and  DOMCharacterDataModified event on the text
#   node.
# - Scripts can be added using document.write, so we need to patch
#   document.write so it adds the script instead of erasing the
#   document.
# - ResourceQueue checks whether this.data is something, if this.data is
#   an empty string it does nothing when check() is called, and so never
#   completes loading when there are empty scripts.

advise = (clazz, method, advice)->
  proto = clazz.prototype
  impl = proto[method]
  proto[method] = ()->
    args = Array.prototype.slice.call(arguments)
    ret = impl.apply(this, arguments)
    args.unshift ret
    return advice.apply(this, args) || ret

# JSDOM had advise for appendChild, but doesn't seem to do much if the
# child is a text node.
advise core.Node, "appendChild", (ret, newChild, refChild)->
  if this.ownerDocument && newChild.nodeType == this.TEXT_NODE
    ev = this.ownerDocument.createEvent("MutationEvents")
    ev.initMutationEvent("DOMNodeInsertedIntoDocument", true, false, this, null, null, null, null)
    newChild.parentNode.dispatchEvent(ev)

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
  script.addEventListener "DOMCharacterDataModified", (event)->
    code = event.target.nodeValue.trim()
    if code.length > 0
      src = this.sourceLocation || {}
      filename = src.file || this.ownerDocument.URL
      if src
        filename += ':' + src.line + ':' + src.col
      filename += '<script>'
      core.resourceLoader.enqueue(this, this._eval, filename)(null, code)
  # Fix text property so it doesn't fail on empty contents
  script.__defineGetter__ "text", ->
    # Handle script with no child elements, but also force script
    # content to never be empty (see bug in ResourceQueue)
    (item.value for item in this.children).join("") + " "
  return script

# Fix document.write so it can handle calling document.write from a
# script while loading the document.
core.HTMLDocument.prototype._write = (html)->
  if @readyState == "loading" && @_parser
    # During page loading, document.write appends to the current element
    open = @_parser.tree.open_elements.last()
    parser = new html5.Parser(document: this)
    node = parser.parse_fragment(html, open.parentNode)
  else
    # When loading page, parse from scratch.
    # After page loading, empty document and parse from scratch.
    @removeChild child for child in @children
    @_parser = new html5.Parser(document: this)
    @_parser.parse(html)
  html
core.HTMLDocument.prototype.writeln = (html)-> @write html + "\n"
