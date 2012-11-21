# Hooks provide an easy extensibility mechanism that lets you mess with the
# browser in various interesting ways.


class Hooks
  constructor: (browser)->
    @chains = {}
    for name, fns of Hooks.chains
      @chains[name] = fns.slice()

  # Add a function to this browser's hook.  The function will be called with
  # list of arguments (depends on the hook) and next hook.
  add: (name, fn)->
    unless typeof(fn) == "function" && fn.length > 0
      throw new Error("Expecting second argument to be a function that accepts one or more arguments")
    chain = @chains[name]
    unless chain
      @chain[name] = chain = []
    chain.push(fn)
    return this

  # Removes a function from the hook.
  remove: (name, fn)->
    if chain = @chains[name]
      index = chain.indexOf(fn)
      if ~index
        chain.splice(index, 1)
    return this

  # Run all functions for the named hook with the supplied aguments.  Returns
  # the result of the first function.
  #
  # For example:
  #   run("loaded", browser, document)
  run: (name, args...)->
    if chain = @chains[name]
      chain = chain.slice()
      index = 0
      callNextFunction = ->
        nextFunction = chain[index]
        index++
        if nextFunction
          return nextFunction(args..., callNextFunction)
        else
          return null
      return callNextFunction()
    return null


# Hook chains added to all browsers.
Hooks.chains = {}

# Adds a function to all browsers' hook.
Hooks.add = (name, fn)->
  chain = Hooks.chains[name]
  unless chain
    Hooks.chains[name] = chain = []
  chain.push(fn)
  return this

# Removes a function from all browsers' hook.
Hooks.remove = (name, fn)->
  chain = Hooks.chains[name]
  if chain
    index = chain.indexOf(fn)
    if ~index
      chain.splice(index, 1)
  return this


module.exports = Hooks
