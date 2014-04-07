const File    = require('fs');
const Module  = require('module');
const traceur = require('traceur');


// All JS files, excluding node_modules, are transpiled using Traceur.
const originalRequireJs = Module._extensions['.js'];
Module._extensions['.js'] = function(module, filename) {
  if (/\/(node_modules|test\/scripts)\//.test(filename)) {
    return originalRequireJs(module, filename);
  } else {
    const source = File.readFileSync(filename, 'utf8');
    const compiled = traceur.compile(source, {
      blockBinding:           true,
      generators:             true,
      generatorComprehension: true,
      asyncFunctions:         true,
      validate:     true,
      filename:     filename,
      sourceMap:    true
    });
    if (compiled.errors.length)
      throw new Error(compiled.errors.join('\n'));
    // No idea when/why Traceur adds an empty export
    const cleaned = compiled.js.replace(/module.exports = {};/g, '');
    return module._compile(cleaned, filename);
  }
};


// Mocha supporting ES6 generators.

const co    = require('co');
const mocha = require('mocha');


mocha.Runnable.prototype.run = function(fn) {
  var self = this;
  var ms = this.timeout();
  var start = new Date();
  var ctx = this.ctx;
  var finished;
  var emitted;

  if (ctx) ctx.runnable(this);

  // timeout
  if (this.async) {
    if (ms) {
      this.timer = setTimeout(function(){
        done(new Error('timeout of ' + ms + 'ms exceeded'));
        self.timedOut = true;
      }, ms);
    }
  }

  // called multiple times
  function multiple(err) {
    if (emitted) return;
    emitted = true;
    self.emit('error', err || new Error('done() called multiple times'));
  }

  // finished
  function done(err) {
    if (self.timedOut) return;
    if (finished) return multiple(err);
    self.clearTimeout();
    self.duration = new Date() - start;
    finished = true;
    fn(err);
  }

  // for .resetTimeout()
  this.callback = done;

  // async
  if (this.async) {
    try {
      this.fn.call(ctx, function(err){
        if (err instanceof Error || toString.call(err) === "[object Error]") return done(err);
        if (null != err) return done(new Error('done() invoked with non-Error: ' + err));
        done();
      });
    } catch (err) {
      done(err);
    }
    return;
  }

  if (this.asyncOnly) {
    return done(new Error('--async-only option in use without declaring `done()`'));
  }

  try {
    if (!this.pending) {
      var result = this.fn.call(ctx);

      if (ms) {
        this.timer = setTimeout(function(){
          done(new Error('timeout of ' + ms + 'ms exceeded'));
          self.timedOut = true;
        }, ms);
      }

      if (result && typeof(result.then) === 'function') {
        result.then(function(){ done(); }, done);
      } else if (result && typeof(result.next) === 'function') {
        co(result)(done);
      } else {
        done();
      }
    }
  } catch (err) {
    fn(err);
  }

};

