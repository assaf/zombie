zombie.js(1) -- Superfast headless full stack testing framework using Node.js
==========================================================================

## The Bite

If you're going to write an insanely fast, headless test tool, how can you not
call it Zombie?  Zombie it is.

Zombie.js is a lightweight framefork for testing client-side JavaScript code in
a simulated environment.  No browser required.

Let's try to sign up to a page and see what happens:

    var zombie = require("zombie");

    // Load the page from localhost
    zombie.visit("http://localhost:3000/", function (err, browser) {

      // Fill email, password and submit form
      browser.
        fill("email", "zombie@underworld.dead").
        fill("password", "eat-the-living").
        pressButton("Sign Me Up!", function(err, browser) {

          // Form submitted, new page loaded.
          assert.equal(browser.text("title"), "Welcome To Brains Depot");

        })

    });

Well, that was easy.


### Walking And Waiting

To start off we're going to need a browser.  A browser maintains state
across requests: history, cookies, HTML 5 local and session stroage.  A
browser has a main window, and typically a document loaded into that
window.

You can create a new `zombie.Browser` and point it at a document, either
by setting the `location` property or calling its `visit` method.  As a
shortcut, you can just call the `zombie.visit` method with a URL and
callback.

The browser will load the document and if the document includes any
scripts, also load and execute these scripts.  It will then process some
events, for example, anything your scripts do on page load.  All of
that, just like a real browser, happens asynchronously.

To wait for the page to fully load and all events to fire, you pass
`visit` a callback function.  This function takes two arguments.  If
everything is successful (page loaded, events run), the callback is
called with `null` and a reference to the browser.  If anything went
wrong (page not loaded, event errors), the callback is called with an
error.

If you worked with Node.js before you're familiar with this callback
pattern.  Every time you see a callback in the Zombie.js API, it works
that way: the first argument is an error, or null if there is no error,
with interesting value in the second argument.

Typically the second argument would be a reference to the browser or
window object you called.  This may seem redudant, but works suprisingly
well when composing with other asynchronous APIs, for example, when
using Zombie.js with Vows.

Whenever you want to wait for all events to be processed, just call
`browser.wait` with a callback.


### Browser API

#### Browser.visit(url, callback)

Shortcut for creating new browser and calling `browser.visit` on it.

#### browser.body => Element

Returns the body Element of the current document.

#### browser.check(field) => this
 
Checks a checkbox.

#### browser.choose(field) => this

Selects a radio box option.

#### browser.clickLink(selector, callback)
 
Clicks on a link. Clicking on a link can trigger other events, load new page,
etc: use a callback to be notified of completion.  Finds link by text content
or selector.

#### browser.clock

The current system clock according to the browser (see also `browser.now`).

#### browser.cookies(domain, path?) => Cookies

Returns all the cookies for this domain/path. Path defaults to "/".

#### browser.document => Document

Returns the main window's document. Only valid after opening a document (see `browser.open`).

#### browser.fill(field, value) => this

Fill in a field: input field or text area.

#### browser.fire(name, target, calback?)

Fire a DOM event.  You can use this to simulate a DOM event, e.g. clicking a
link.  These events will bubble up and can be cancelled.  With a callback, this
function will call `wait`.

#### browser.html(selector?, context?) => String

Returns the HTML contents of the selected elements.

#### browser.last_error => Object

Returns the last error received by this browser in lieu of response.

#### browser.last_request => Object

Returns the last request sent by this browser.

#### browser.last_response => Object
 
Returns the last response received by this browser.

#### brower.localStorage(host) => Storage
    
Returns local Storage based on the document origin (hostname/port).

#### browser.location => Location

Return the location of the current document (same as `window.location.href`).

#### browser.location = url

Changes document location, loads new document if necessary (same as setting
`window.location`).

#### browser.now => Date

The current system time according to the browser (see also `browser.clock`).

#### browser.open() => Window
 
Open new browser window.

#### browser.pressButton(name, callback)
 
Press a button (button element or input of type `submit`).  Typically this will
submit the form.  Use the callback to wait for the from submission, page to
load and all events run their course.

#### browser.querySelector(selector) => Element

Select a single element (first match) and return it.

#### browser.querySelectorAll(selector) => NodeList

Select multiple elements and return a static node list.

#### browser.select(field, value) => this
 
Selects an option.

#### brower.sessionStorage(host) => Storage

Returns session Storage based on the document origin (hostname/port).

#### browser.text(selector, context?) => String

Returns the text contents of the selected elements.

#### browser.uncheck(field) => this

Unchecks a checkbox.

#### browser.visit(url, callback)

Loads document from the specified URL, processes events and calls the callback.

#### browser.wait(terminator, callback)

Process all events from the queue.  This includes resource loading, XHR
requests, timeout and interval timers.  Calls the callback when done.

The terminator is optional and can be one of:
* `null`, missing -- process all events
* Number -- process that number of events
* Function -- called after each event, returns false to stop processing

#### browser.window => Window

Returns the main window.



## Guts

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


## Feeding

* Find [assaf/zombie on Github](http://github.com/assaf/zombie)
* Fork the project
* Add tests
* Make your changes
* Send a pull request

Check out the outstanding [to-dos](todo.html).


## Brains

Zombie.js is copyright of [Assaf Arkin](http://labnotes.org), released under the MIT License.

Zombie.js is written in
[CoffeeScript](http://jashkenas.github.com/coffee-script/) for
[Node.js](http://nodejs.org/).

[Sizzle.js](http://sizzlejs.com/) is copyright of John Resig, released under the MIT, BSD and GPL.


## See Also

[Annotated Source Code](source/browser.html) for Zombie.js.

[Changelog](changelog.html)

[Sizzle.js](https://github.com/jeresig/sizzle/wiki) documentation.

[Vows](http://vowsjs.org/) You don't have to, but I really recommend
running Zombie.js with Vows, an outstanding BDD test framework for
Node.js.
