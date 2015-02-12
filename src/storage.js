// See [Web Storage](http://dev.w3.org/html5/webstorage/)
const DOM = require('./dom');


// Implementation of the StorageEvent.
class StorageEvent extends DOM.Event {

  constructor(storage, url, key, oldValue, newValue) {
    super('storage');
    this._storage   = storage;
    this._url       = url;
    this._key       = key;
    this._oldValue  = oldValue;
    this._newValue  = newValue;
  }

  get url() {
    return this._url;
  }
  get storageArea() {
    return this._storage;
  }
  get key() {
    return this._key;
  }
  get oldValue() {
    return this._oldValue;
  }
  get newValue() {
    return this._newValue;
  }
}


// Storage area. The storage area is shared by multiple documents of the same
// origin. For session storage, they must also share the same browsing context.
class StorageArea {

  constructor() {
    this._items     = new Map();
    this._storages  = [];
  }

  // Fire a storage event. Fire in all documents that share this storage area,
  // except for the source document.
  _fire(source, key, oldValue, newValue) {
    for (let [storage, window] of this._storages) {
      if (storage === source)
        continue;
      const event = new StorageEvent(storage, window.location.href, key, oldValue, newValue);
      window.dispatchEvent(event);
    }
  }

  // Return number of key/value pairs.
  get length() {
    return this._items.size;
  }

  // Get key by ordinal position.
  key(index) {
    const keys = [...this._items.keys()];
    return keys[index];
  }

  // Get value from key
  get(key) {
    return this._items.get(key) || null;
  }

  // Set the value of a key. We also need the source storage (so we don't send
  // it a storage event).
  set(source, key, value) {
    const oldValue = this._items.get(key);
    this._items.set(key, value);
    this._fire(source, key, oldValue, value);
  }

  // Remove the value at the key. We also need source storage (see set above).
  remove(source, key) {
    const oldValue = this._items.get(key);
    this._items.delete(key);
    this._fire(source, key, oldValue);
  }

  // Remove all values. We also need source storage (see set above).
  clear(source) {
    this._items.clear();
    this._fire(source);
  }

  get pairs() {
    return [...this._items.entries()];
  }

  toString() {
    this.pairs()
      .map((name, value)=> `${name} = ${value}`)
      .join('\n');
  }

  // Associate local/sessionStorage and window with this storage area. Used when firing events.
  associate(storage, window) {
    this._storages.push([storage, window]);
  }

}


// Implementation of the Storage interface, used by local and session storage.
class Storage {

  constructor(area) {
    this._area = area;
  }

  // ### storage.length => Number
  //
  // Returns the number of key/value pairs in this storage.
  get length() {
    return this._area.length;
  }
  
  // ### storage.key(index) => String
  //
  // Returns the key at this position.
  key(index) {
    return this._area.key(index);
  }
  
  // ### storage.getItem(key) => Object
  //
  // Returns item by key.
  getItem(key) {
    return this._area.get(key.toString());
  }
  
  // ### storage.setItem(key, Object)
  //
  // Add item or change value of existing item.
  setItem(key, value) {
    this._area.set(this, key.toString(), value);
  }
  
  // ### storage.removeItem(key)
  //
  // Remove item.
  removeItem(key) {
    this._area.remove(this, key.toString());
  }
  
  // ### storage.clear()
  //
  // Remove all items.
  clear() {
    this._area.clear(this);
  }
  
  // Dump to a string, useful for debugging.
  dump() {
    return this._area.dump();
  }

}
  



// Combined local/session storage.
class Storages {

  constructor() {
    this._locals    = {};
    this._sessions  = {};
  }

  // Return local Storage based on the document origin (hostname/port).
  local(host) {
    if (!this._locals[host])
      this._locals[host] = new StorageArea();
    return new Storage(this._locals[host]);
  }

  // Return session Storage based on the document origin (hostname/port).
  session(host) {
    if (!this._sessions[host])
      this._sessions[host] = new StorageArea();
    return new Storage(this._sessions[host]);
  }

  // Extend window with local/session storage support.
  extend(window) {
    const storages = this;
    window.StorageEvent = StorageEvent;
    Object.defineProperties(window, {
      localStorage: {
        get() {
          const { document } = this;
          if (!document._localStorage)
            document._localStorage = storages.local(document.location.host);
          return document._localStorage;
        }
      },
      sessionStorage: {
        get() {
          const { document } = this;
          if (!document._sessionStorage)
            document._sessionStorage = storages.session(document.location.host);
          return document._sessionStorage;
        }
      },
    });
  }

  // Used to dump state to console (debuggin)
  dump() {
    const serialized = [];
    for (let domain of this._locals) {
      let area = this._locals[domain];
      serialized.push(`${domain} local:`);
      for (let [name, value] of area.pairs)
        serialized.push(`  ${name} = ${value}`);
    }
    for (let domain of this._sessions) {
      let area = this._sessions[domain];
      serialized.push(`${domain} session:`);
      for (let [name, value] of area.pairs)
        serialized.push(`  ${name} = ${value}`);
    }
    return serialized;
  }

  // browser.saveStorage uses this
  save() {
    const serialized = [`# Saved on ${new Date().toISOString()}`];
    for (let domain of this._locals) {
      let area = this._locals[domain];
      let pairs = area.pairs;
      if (pairs.length) {
        serialized.push(`${domain} local:`);
        for (let [name, value] of area.pairs)
          serialized.push(`  ${escape(name)} = ${escape(value)}`);
      }
    }
    for (let domain of this._sessions) {
      let area = this._sessions[domain];
      let pairs = area.pairs;
      if (pairs.length) {
        serialized.push(`${domain} session:`);
        for (let [name, value] of area.pairs)
          serialized.push(`  ${escape(name)} = ${escape(value)}`);
      }
    }
    return serialized.join(`\n`) + `\n`;
  }
    
  // browser.loadStorage uses this
  load(serialized) {
    let storage = null;
    for (let item of serialized.split(/\n+/)) {
      if (item[0] === '#' || item === '')
        continue;
      if (item[0] === ' ') {
        const [key, value] = item.split('=');
        if (storage)
          storage.setItem(unescape(key.trim()), unescape(value.trim()));
        else
          throw new Error('Must specify storage type using local: or session:');
      } else {
        const [domain, type] = item.split(' ');
        if (type === 'local:') {
          storage = this.local(domain);
        } else if (type === 'session:') {
          storage = this.session(domain);
        } else
          throw new Error(`Unkown storage type ${type}`);
      }
    }
  }
}


module.exports = Storages;

