fs = require("fs")
sizzle = fs.readFileSync(__dirname + "/../../dep/sizzle.js", "utf8")
core = require("jsdom").dom.level3.core

close = core.HTMLDocument.prototype.close
core.HTMLDocument.prototype.close = ->
  close.call this
  window = @parentWindow

  # Load Sizzle and add window.find. This only works if we parsed a document.
  if @documentElement
    ctx = process.binding("evals").Script.createContext(window)
    ctx.window = window
    ctx.document = this
    process.binding("evals").Script.runInContext sizzle, ctx
    Sizzle = window.Sizzle
    @find = (selector, context)-> new Sizzle(selector, context)
