zombie.js(1) -- Superfast headless full stack testing framework using Node.js
==========================================================================

The Bite
--------

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

See the documentation for [Sizzle.js](https://github.com/jeresig/sizzle/wiki).

[Source code/API Documentation](source/browser.html)


Guts
----

Zombie.js is written in
[CoffeeScript](http://jashkenas.github.com/coffee-script/), a language
that mixes the best parts of Python and Ruby and compiles one-to-one
into JavaScript.

To get started hacking on Zombie.js you'll need Node.js, NPM and
CoffeeScript:

    $ brew install node npm
    $ npm install coffee-script

Next, install all other development and runtime dependencies:

    $ cake setup

The DOM implementation is [JSDOM](http://jsdom.org/), which provides
pretty decent emulation of DOM Level 3. There are some issues and some
features Zombie.js needs but JSDOM doesn't care for (e.g default event
handlers).  Those are patched onto JSDOM in
`lib/zombie/jsdom_patches.coffee` and `lib/zombie/forms.coffee`.

DOM selectors are provided by [Sizzle.js](http://sizzlejs.com/), and
vendored in the `vendor` directory.

Zombie.js is tested using [Vows](http://vowsjs.org/).  Since we're
testing a Web browser, we also need a Web server, so it spins up an
instance of [Express](http://expressjs.com/).  Spinning up Express and
making sure it doesn't power down before all tests are done (Vows is
asynchronous, like everything in Node) is the responsibility of
`spec/helper.coffee`.

To run the test suite:

    $ vows

To stress Zombie.js, we have test cases that use Sammy.js and jQuery.
The scripts themselves are contained in the `spec/.scripts` directory.
The dot is necessary to hide these JS files from Vows.

Zombie.js documentation is written in
[Markdown](http://daringfireball.net/projects/markdown/syntax#code).

Everything you need to know to get started is covered by `README.md`, so
it shows up when you visit the [Github
page](http://github.com/assaf/zombie).

Additional documentation lives in the `doc` directory.  Annotated source
code generated using [Docco](http://jashkenas.github.com/docco/).

To generate the documentation

    $ cake doc
    $ open html/index.html


Feeding
-------

* Find [assaf/zombie on Github](http://github.com/assaf/zombie)
* Fork the project
* Add tests
* Make your changes
* Send a pull request

Check out the outstanding [to-dos](todo.html).


Brains
------

Zombie.js is copyright of [Assaf Arkin](http://labnotes.org), released under the MIT License.

Zombie.js is written in
[CoffeeScript](http://jashkenas.github.com/coffee-script/) for
[Node.js](http://nodejs.org/).

[Sizzle.js](http://sizzlejs.com/) is copyright of John Resig, released under the MIT, BSD and GPL.
