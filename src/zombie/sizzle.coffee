# Implementation of the [DOM Selector API](http://www.w3.org/TR/selectors-api/)
fs = require("fs")
vm = process.binding("evals")
sizzle = new vm.Script(fs.readFileSync(__dirname + "/../../vendor/sizzle.js", "utf8"), "sizzle.js")
html = require("jsdom").dom.level3.html

close = html.HTMLDocument.prototype.close
html.HTMLDocument.prototype.close = ->
  close.call this
  window = @parentWindow

  # Load Sizzle. This only works if we parsed a document.
  if window && @documentElement
    ctx = vm.Script.createContext(window)
    ctx.window = window
    ctx.document = this
    # Sizzle will look for querySelectorAll, we use Sizzle to implement
    # querySelectorAll, hilarity ensues.  Fortunately, all we need to do
    # is hide that one function.
    selector = ctx.document.querySelectorAll
    ctx.document.querySelectorAll = null
    sizzle.runInContext ctx
    ctx.document.querySelectorAll = selector
    @find = (selector, context)-> new window.Sizzle(selector, context)

html.HTMLDocument.prototype.querySelector = (selector)->
  @parentWindow.Sizzle(selector, this)[0]
html.HTMLDocument.prototype.querySelectorAll = (selector)->
  new html.NodeList(this, => @parentWindow.Sizzle(selector, this))
html.HTMLElement.prototype.querySelector = (selector)->
  @ownerDocument.parentWindow.Sizzle(selector, this)[0]
html.HTMLElement.prototype.querySelectorAll = (selector)->
  new html.NodeList(@ownerDocument, => @ownerDocument.parentWindow.Sizzle(selector, this))
