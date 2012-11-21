# Hooks provide an easy extensibility mechanism that lets you mess with the
# browser in various interesting ways.


class Hooks
  constructor: (browser)->
    @_hooks = {}
    for name, hooks of globalHooks
      @_hooks[name] = hooks.slice()

  # Same as addHook.
  on: (name, fn)->
    @addHook(name, fn)

  # Add a function to this browser's hook.  The function will be called with
  # list of arguments (depends on the hook) and next hook.
  addHook: (name, fn)->
    unless typeof(fn) == "function" && fn.length > 0
      throw new Error("Expecting second argument to be a function that accepts one or more arguments")
    hooks = @_hooks[name]
    unless hooks
      @_hooks[name] = hooks = []
    hooks.push(fn)
    return

  # Removes a function from the hook.
  removeHook: (name, fn)->
    if hooks = @_hooks[name]
      index = hooks.indexOf(fn)
      if ~index
        hooks.splice(index, 1)
    return

  # Returns all functions associated with the given hook name.
  hooks: (name)->
    if hooks = @_hooks[name]
      return hooks.slice()
    else
      return []

  # Run all functions for the named hook with the supplied aguments.  Returns
  # the result of the first function.
  #
  # For example:
  #   run("loaded", browser, document)
  run: (name, args...)->
    hooks = @hooks(name)
    index = 0
    callNextFunction = ->
      nextFunction = hooks[index]
      index++
      if nextFunction
        return nextFunction(args..., callNextFunction)
      else
        return null
    return callNextFunction()


# Hook chains added to all browsers.
globalHooks = {}

# Adds a function to all browsers' hook.
Hooks.addHook = (name, fn)->
  hooks = globalHooks[name]
  unless hooks
    globalHooks[name] = hooks = []
  hooks.push(fn)
  return

# Removes a function from all browsers' hook.
Hooks.removeHook = (name, fn)->
  hooks = globalHooks[name]
  if hooks
    index = hooks.indexOf(fn)
    if ~index
      hooks.splice(index, 1)
  return

# Returns all functions associated with the given hook name.
Hooks.hooks = (name)->
  if hooks = globalHooks[name]
    return hooks.slice()
  else
    return []


module.exports = Hooks
