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
    window.find = (selector, context)-> new Sizzle(selector, context)

    # Add default behavior for clicking links
    document.addEventListener "click", (evt)=>
      return if evt._preventDefault
      target = evt.target
      switch target.nodeName
        when "A" then window.location = target.href if target.href
        when "INPUT"
          if form = target.form
            switch target.type
              when "reset" then target.form.reset()
              when "submit" then target.form._dispatchSubmitEvent()
