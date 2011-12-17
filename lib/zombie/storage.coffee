# See [Web Storage](http://dev.w3.org/html5/webstorage/)
HTML = require("jsdom").dom.level3.html
Events = require("jsdom").dom.level3.events


# Storage area. The storage area is shared by multiple documents of the same
# origin. For session storage, they must also share the same browsing context.
class StorageArea
  constructor: ->
    @_items = []
    @_storages = []

  # Fire a storage event. Fire in all documents that share this storage area,
  # except for the source document.
  _fire: (source, key, oldValue, newValue)->
    for [storage, window] in @_storages
      continue if storage == source
      event = new StorageEvent(storage, window.location.href, key, oldValue, newValue)
      window.browser.dispatchEvent window, event

  # Return number of key/value pairs.
  @prototype.__defineGetter__ "length", ->
    i = 0
    ++i for k of @_items
    return i

  # Get key by ordinal position.
  key: (index)->
    i = 0
    for k of @_items
      return k if i == index
      ++i
    return

  # Get value from key
  get: (key)->
    return @_items[key]

  # Set the value of a key. We also need the source storage (so we don't send
  # it a storage event).
  set: (source, key, value)->
    oldValue = @_items[key]
    @_items[key] = value
    @_fire source, key, oldValue, value

  # Remove the value at the key. We also need source storage (see set above).
  remove: (source, key)->
    oldValue = @_items[key]
    delete @_items[key]
    @_fire source, key, oldValue

  # Remove all values. We also need source storage (see set above).
  clear: (source)->
    @_items = []
    @_fire source

  # Associate local/sessionStorage and window with this storage area. Used when firing events.
  associate: (storage, window)->
    @_storages.push [storage, window]

  @prototype.__defineGetter__ "pairs", ->
    return ([k,v] for k,v of @_items)

  toString: ->
    return ("#{k} = #{v}" for k,v of @_items).join("\n")


# Implementation of the Storage interface, used by local and session storage.
class Storage
  constructor: (@_area)->
  
  # ### storage.length => Number
  #
  # Returns the number of key/value pairs in this storage.
  @prototype.__defineGetter__ "length", ->
    return @_area.length
  
  # ### storage.key(index) => String
  #
  # Returns the key at this position.
  key: (index)->
    return @_area.key(index)
  
  # ### storage.getItem(key) => Object
  #
  # Returns item by key.
  getItem: (key)->
    return @_area.get(key.toString())
  
  # ### storage.setItem(key, Object)
  #
  # Add item or change value of existing item.
  setItem: (key, value)->
    @_area.set this, key.toString(), value
  
  # ### storage.removeItem(key)
  #
  # Remove item.
  removeItem: (key)->
    @_area.remove this, key.toString()
  
  # ### storage.clear()
  #
  # Remove all items.
  clear: ->
    @_area.clear this
  
  # Dump to a string, useful for debugging.
  dump: ->
    return @_area.dump()


# Implementation of the StorageEvent.
StorageEvent = (storage, url, key, oldValue, newValue)->
  Events.Event.call this, "storage"
  @__defineGetter__ "url", ->
    return url
  @__defineGetter__ "storageArea", ->
    return storage
  @__defineGetter__ "key", ->
    return key
  @__defineGetter__ "oldValue", ->
    return oldValue
  @__defineGetter__ "newValue", ->
    return newValue
StorageEvent.prototype.__proto__ = Events.Event.prototype


# Additional error codes defines for Web Storage and not in JSDOM.
HTML.SECURITY_ERR = 18


# Combined local/session storage.
class Storages
  constructor: ->
    @_locals = {}
    @_sessions = {}

  # Return local Storage based on the document origin (hostname/port).
  local: (host)->
    area = @_locals[host] ?= new StorageArea()
    return new Storage(area)

  # Return session Storage based on the document origin (hostname/port).
  session: (host)->
    area = @_sessions[host] ?= new StorageArea()
    return new Storage(area)

  # Extend window with local/session storage support.
  extend: (window)->
    storages = this
    Object.defineProperty window, "localStorage",
      get: ->
        return @document?._localStorage ||= storages.local(@location.host)
    Object.defineProperty window, "sessionStorage",
      get: ->
        return @document?._sessionStorage ||= storages.session(@location.host)

  # Used to dump state to console (debuggin)
  dump: ->
    serialized = []
    for domain, area of @_locals
      pairs = area.pairs
      serialized.push "#{domain} local:"
      for pair in pairs
        serialized.push "  #{pair[0]} = #{pair[1]}"
    for domain, area of @_sessions
      pairs = area.pairs
      serialized.push "#{domain} session:"
      for pair in pairs
        serialized.push "  #{pair[0]} = #{pair[1]}"
    return serialized

  # browser.saveStorage uses this
  save: ->
    serialized = ["# Saved on #{new Date().toISOString()}"]
    for domain, area of @_locals
      pairs = area.pairs
      if pairs.length > 0
        serialized.push "#{domain} local:"
        for pair in pairs
          serialized.push "  #{escape pair[0]} = #{escape pair[1]}"
    for domain, area of @_sessions
      pairs = area.pairs
      if pairs.length > 0
        serialized.push "#{domain} session:"
        for pair in pairs
          serialized.push "  #{escape pair[0]} = #{escape pair[1]}"
    return serialized.join("\n") + "\n"
    
  # browser.loadStorage uses this
  load: (serialized) ->
    storage = null
    for item in serialized.split(/\n+/)
      continue if item[0] == "#" || item == ""
      if item[0] == " "
        [key, value] = item.split("=")
        if storage
          storage.setItem unescape(key.trim()), unescape(value.trim())
        else
          throw "Must specify storage type using local: or session:"
      else
        [domain, type] = item.split(" ")
        if type == "local:"
          storage = @local(domain)
        else if type == "session:"
          storage = @session(domain)
        else
          throw "Unkown storage type #{type}"


module.exports = Storages
