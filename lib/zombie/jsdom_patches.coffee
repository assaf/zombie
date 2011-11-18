# Fix things that JSDOM doesn't do quite right.
html = require("jsdom").dom.level3.html
URL = require("url")


html.HTMLElement.prototype.__defineGetter__ "offsetLeft",   -> 0
html.HTMLElement.prototype.__defineGetter__ "offsetTop",    -> 0
html.HTMLElement.prototype.__defineGetter__ "offsetWidth",  -> 100
html.HTMLElement.prototype.__defineGetter__ "offsetHeight", -> 100


# Default behavior for clicking on links: navigate to new URL is specified.
html.HTMLAnchorElement.prototype._eventDefaults =
  click: (event)->
    anchor = event.target
    anchor.ownerDocument.parentWindow.location = anchor.href if anchor.href

# Fix resource loading to keep track of in-progress requests. Need this to wait
# for all resources (mainly JavaScript) to complete loading before terminating
# browser.wait.
html.resourceLoader.load = (element, href, callback)->
  document = element.ownerDocument
  window = document.parentWindow
  ownerImplementation = document.implementation
  tagName = element.tagName.toLowerCase()

  if ownerImplementation.hasFeature('FetchExternalResources', tagName)
    switch tagName
      when "iframe"
        element.window.location = URL.resolve(element.window.parent.location, href)

      else
        url = URL.parse(@resolve(document, href))
        loaded = (response, filename)->
          callback.call this, response.body, URL.parse(response.url).pathname
        if url.hostname
          window.resources.get url, @enqueue(element, loaded, url.pathname)
        else
          file = @resolve(document, url.pathname)
          @readFile file, @enqueue(element, loaded, file)


###
html.Document.prototype._elementBuilders["iframe"] = (doc, s)->
  window = doc.parentWindow

  iframe = new html.HTMLIFrameElement(doc, s)
  iframe.window = window.browser.open(interactive: false)
  iframe.window.parent = window

  return iframe
###



# If JSDOM encounters a JS error, it fires on the element.  We expect it to be
# fires on the Window.  We also want better stack traces.
html.languageProcessors.javascript = (element, code, filename)->
  if doc = element.ownerDocument
    window = doc.parentWindow
    try
      window.run code, filename
    catch error
      # Deconstruct the stack trace and strip the Zombie part of it
      # (anything leading to this file).  Add the document location at
      # the end.
      partial = []
      for line in error.stack.split("\n")
        break if ~line.indexOf(__filename)
        partial.push line
      partial.push "    in #{doc.location.href}"
      error.stack = partial.join("\n")
      
      event = doc.createEvent("Event")
      event.initEvent "error", false, false
      event.message = error.message
      event.error = error
      window.dispatchEvent event
