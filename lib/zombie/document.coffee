fs = require("fs")
sizzle = fs.readFileSync(__dirname + "/../../dep/sizzle.js", "utf8")

exports.apply = (window)->
  window.enhance = (document)->
    # Add window.select
    ctx = process.binding("evals").Script.createContext(window)
    ctx.window = window
    ctx.document = document
    process.binding("evals").Script.runInContext sizzle, ctx
    Sizzle = window.Sizzle
    window.select = (selector, context)-> new Sizzle(selector, context)

    # Add default behavior for clicking links
    document.addEventListener "click", (evt)=>
      if evt.target.nodeName == "A" && href = evt.target.href
        window.location = href
