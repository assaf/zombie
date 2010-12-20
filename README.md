Zombie.js
=========

If you're going to write an insanely fast, headless test tool, how can you not
call it Zombie?  Zombie it is.

Zombie.js is a lightweight framefork for testing client-side JavaScript code in
a simulated environment.  No browser required.

Zombie.js runs on [Node.js](http://nodejs.org/), so it's insanely fast.  It
uses [JSDOM](http://jsdom.org/) to simulate a brower, so it can't find
incompatibility issues in IE 7.0, but it can spot bugs in your code.

You don't have to, but I really recommend running Zombie.js with
[Vows](http://vowsjs.org/) , an outstanding BDD test framework for Node.js.


Using
-----

Coming.


Feeding
-------

See the documentation for [Sizzle.js](https://github.com/jeresig/sizzle/wiki).


Bleeding Edge
-------------

For a full list of runtime dependencies, see [package.json](https://github.com/assaf/zombie/blob/master/package.json).

The test suite requires [Vows 0.5.x](http://vowsjs.org/) and [Express 1.0.x](http://expressjs.com/):

    $ npm install vows
    $ npm install express
    $ cake test

For documentation you'll need [Ronn 0.3.x](https://github.com/kapouer/ronnjs) and [Docco 0.3](http://jashkenas.github.com/docco/):

    $ npm install ronn
    $ npm install docco


Contributing
------------

* Fork the project.
* Add tests.
* Make your changes.
* Send me a pull request.


Brains
------

Zombie.js is copyright of [Assaf Arkin](http://labnotes.org), released under the MIT License.

Zombie.js is written in [CoffeeScript](http://jashkenas.github.com/coffee-script/).

[Sizzle.js](http://sizzlejs.com/) is copyright of John Resig, released under the MIT, BSD and GPL.
