# Select document elements using Sizzle.js.
fs = require("fs")
vm = process.binding("evals")
sizzle = new vm.Script(fs.readFileSync(__dirname + "/../../vendor/sizzle.js", "utf8"), "sizzle.js")
core = require("jsdom").dom.level3.core

close = core.HTMLDocument.prototype.close
core.HTMLDocument.prototype.close = ->
  close.call this
  window = @parentWindow

  # Load Sizzle and add window.find. This only works if we parsed a document.
  if window && @documentElement
    ctx = vm.Script.createContext(window)
    ctx.window = window
    ctx.document = this
    sizzle.runInContext ctx
    @find = (selector, context)-> new window.Sizzle(selector, context)
