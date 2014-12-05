# Lazy promises don't evaluate until you register the first fulfilled or
# rejected handler.

{ Promise }       = require("bluebird")


THEN_METHODS = [ 'call', 'catch', 'done', 'error', 'finally', 'get', 'reflect', 'return', 'tap', 'then', 'throw' ]
INSPECTION_METHODS = [ 'isFulfilled', 'isPending', 'isRejected', 'reason', 'value' ]

LazyPromise = (resolver)->
  unless typeof(resolver) == 'function' || resolver instanceof Function
    throw new Error("Must be called with resolver callback")
  this._resolver = resolver
  this._resolved = false
  this._promise  = new Promise(=>
    this._resolve = arguments[0]
    this._reject  = arguments[1]
  )
  return this

LazyPromise.prototype._lazyResolve = ->
  if !this._resolved
    setImmediate =>THEN_METHODS = [ 'call', 'catch', 'done', 'error', 'finally', 'get', 'reflect', 'return', 'tap', 'then', 'throw' ]
INSPECTION_METHODS = [ 'isFulfilled', 'isPending', 'isRejected', 'reason', 'value' ]

LazyPromise = (resolver)->
  unless typeof(resolver) == 'function' || resolver instanceof Function
    throw new Error("Must be called with resolver callback")
  this._resolver = resolver
  this._resolved = false
  this._promise  = new Promise(=>
    this._resolve = arguments[0]
    this._reject  = arguments[1]
  )
  return this

LazyPromise.prototype._lazyResolve = ->
  if !this._resolved
    setImmediate =>
      try
        this._resolver(this._resolve, this._reject)
      catch ex
        this._reject(ex)
    this._resolved = true

THEN_METHODS.forEach (name)->
  method = Promise.prototype[name]
  LazyPromise.prototype[name] = ->
    this._lazyResolve()
    return method.apply(this._promise, arguments)

INSPECTION_METHODS.forEach (name)->
  method = Promise.prototype[name]
  LazyPromise.prototype[name] = ->
    return method.apply(this._promise, arguments)


module.exports = LazyPromise
