Vows = require("vows")
assert = require("assert")
JSDOM = require("jsdom")
URL = require("url")
_ = require("underscore")


# Fix not-too-smart URL resolving in JSDOM.
JSDOM.dom.level3.core.resourceLoader.resolve = (document, path)->
  path = URL.resolve(document.URL, path)
  path.replace(/^file:/, '').replace(/^([\/]+)/, "/")
JSDOM.dom.level3.core.resourceLoader.load = (element, href, callback)->
  document = element.ownerDocument
  ownerImplementation = document.implementation
  if ownerImplementation.hasFeature('FetchExternalResources', element.tagName.toLowerCase())
    url = URL.parse(@resolve(document, href))
    if url.hostname
      @download url, @enqueue(element, callback, url.pathname)
    else
      file = @resolve(document, url.pathname)
      @readFile file, @enqueue(element, callback, file)



app = require("express").createServer()
app.get("/", (req, res)->
  console.log "Processing request"
  res.send "Hello World"
)
app.listen 3001


class Location
  constructor: (@window)-> @url = URL.parse("")
  replace: (url)->
    @url = URL.parse(url)
    document = @window.document
    loader = JSDOM.dom.level3.core.resourceLoader
    loader.download @url, (err, data)->
      if err
        ev = document.createEvent('HTMLEvents')
        ev.initEvent "error", false, false
        element.dispatchEvent ev
      else
        document.open()
        document.write(data)
        document.close()
  toString: -> URL.format(@url)
for prop in ["href", "protocol", "host", "port", "hostname", "search", "query", "pathname"]
  Location.prototype.__defineGetter__ prop, -> @url[prop]
  Location.prototype.__defineSetter__ prop, (value)->
    @url[prop] = value
    @replace URL.format(@url)


# Use the browser to open up new windows and load documents.
#
# The browser maintains state for cookies and localStorage.
class Browser
  constructor: ->
  # Opens a new window, laods document from the specified URL and returns the
  # window.
  open: (url, callback)->
    document = JSDOM.jsdom(null, null, url: url)
    window = document.parentWindow
    # Getting location returns Location object, setting changes page URL.
    window._location = new Location(window)
    window.__defineGetter__ "location", -> @_location
    window.__defineSetter__ "location", (url)-> @_location.replace(url)

    window.XMLHttpRequest = -> {}
    window.setTimeout = (fn, delay, context)->
    window.setInterval = (fn, delay, context)->
    window.clearInterval = (timer)->
    window.clearTimeout = (timer)->

    # Hook into event  
    document.addEventListener "DOMContentLoaded", -> callback null, window.document
    document.addEventListener "error", (err)-> callback err
    window.location = url
  cookies: {}
  localStorage: {}

Vows.describe("Browser").addBatch({
  "open page":
    topic: ()->
      new Browser().open("http://localhost:3000/", @callback)
      return
    "callback with document": (document)->
      assert.ok document, "not a document"
      assert.ok document instanceof JSDOM.dom.level3.html.HTMLDocument, "not a document"
    "load document": (document)->
      html = document.outerHTML
      assert.ok /<title>Flowtown<\/title>/.test(html), "HTML document without title"
    "load scripts": (document)->
      assert.ok jQuery = document.parentWindow.jQuery, "window.jQuery not available"
      assert.ok _.isFunction(jQuery.ajax), "window.jQuery has no ajax function?"
}).run(null, -> app.close()) 
