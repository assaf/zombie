class Accessors
  @get: (name, fn)->
    @prototype.__defineGetter__ name, fn

  @set: (name, fn)->
    @prototype.__defineSetter__ name, fn


exports.Accessors = Accessors
