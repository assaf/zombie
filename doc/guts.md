guts-zombie.js(1) -- The Guts
=============================


## Hacking

To get started hacking on Zombie.js you'll need Node.js and NPM:

    $ brew install node
    $ curl http://npmjs.org/install.sh | sudo sh

Next install all the runtime and development dependencies:

    $ npm install

To run the test suite:

    $ npm test

If you're hacking on Zombie and testing it in a different project, you
can "install" your working directory using `npm link`.

To generate the documentation:

    $ make doc
    $ open html/index.html


## Grocking

Zombie.js is written in
[CoffeeScript](http://jashkenas.github.com/coffee-script/), a language
that mixes the best parts of Python and Ruby and compiles one-to-one
into JavaScript.

The DOM implementation is [JSDOM](http://jsdom.org/), which provides an
emulation of DOM Level 3. There are some issues and some features
Zombie.js needs but JSDOM doesn't care for.  Those are patched onto
JSDOM in `lib/zombie/jsdom_patches.coffee` and
`lib/zombie/forms.coffee`.

HTML5 parsing is handled by [HTML5](https://github.com/aredridel/html5).

DOM selectors are provided by JSDOM using [Sizzle.js](http://sizzlejs.com/).


## Testing

Zombie.js is tested using [Mocha](http://visionmedia.github.com/mocha/).

Since we're testing a Web browser, we also need a Web server, so it
spins up an instance of [Express](http://expressjs.com/).  Spinning up
Express and making sure it doesn't power down before all tests are done
(Vows is asynchronous, like everything in Node) is the responsibility of
`spec/helper.coffee`.

To stress Zombie.js, we have test cases that use Sammy.js and jQuery.
The scripts themselves are contained in the `spec/.scripts` directory.
The dot is necessary to hide these JS files from Vows.


## Documenting

Zombie.js documentation is written in
[Markdown](http://daringfireball.net/projects/markdown/syntax#code).

Everything you need to know to get started is covered by `README.md`, so
it shows up when you visit the [Github
page](http://github.com/assaf/zombie).

Additional documentation lives in the `doc` directory.  Annotated source
code generated using [Docco](http://jashkenas.github.com/docco/).

