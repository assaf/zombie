zombie.js(1) -- Zombie.js
=========================

**Insanely fast, headless full-stack testing using Node.js**

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


## Walking

To start off we're going to need a browser.  A browser maintains state
across requests: history, cookies, HTML 5 local and session stroage.  A
browser has a main window, and typically a document loaded into that
window.

You can create a new `zombie.Browser` and point it at a document, either
by setting the `location` property or calling its `visit` function.  As
a shortcut, you can just call the `zombie.visit` function with a URL and
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


## Hunting

There are several ways you can inspect the contents of a document.  For
starters, there's the [DOM API](http://www.w3.org/DOM/DOMTR), which you
can use to find elements and traverse the document tree.

You can also use CSS selectors to pick a specific element or node list.
Zombie.js implements the [DOM Selector
API](http://www.w3.org/TR/selectors-api/).  These functions are
available from every element, the document, and the `Browser` object
itself.

To get the HTML contents of an element, read its `innerHTML` property.
If you want to include the element itself with its attributes, read the
element's `outerHTML` property instead.  Alternatively, you can call the
`browser.html` function with a CSS selector and optional context
element.  If the function selects multiple elements, it will return the
combined HTML of them all.

To see the textual contents of an element, read its `textContent`
property.  Alternatively, you can call the `browser.text` function with
a CSS selector and optional context element.  If the function selects
multiple elements, it will return the combined text contents of them
all.

Here are a few examples for checking the contents of a document:

    // Make sure we have an element with the ID brains.
    assert.ok(browser.querySelector("#brains"));

    // Make sure body has two elements with the class hand.
    assert.equal(browser.body.querySelectorAll(".hand").length, 2);

    // Check the document title.
    assert.equal(browser.text("title"), "The Living Dead");

    // Show me the document contents.
    console.log(browser.html());

    // Show me the contents of the parts table:
    console.log(browser.html("table.parts"));

CSS selectors are implemented by Sizzle.js.  In addition to CSS 3
selectors you get additional and quite useful extensions, such as
`:not(selector)`, `[NAME!=VALUE]`, `:contains(TEXT)`, `:first/:last` and
so forth.  Check out the [Sizzle.js
documentation](https://github.com/jeresig/sizzle/wiki) for more details.


## Feeding

You're going to want to perform some actions, like clicking links,
entering text, submitting forms.  You can certainly do that using the
[DOM API](http://www.w3.org/DOM/DOMTR), or several of the convenience
functions we're going to cover next.

To click a link on the page, use `clickLink` with selector and callback.
The first argument can be a CSS selector (see _Hunting_) or the text
contents of the `A` element you want to click.  The second argument is a
callback, which is passed on to `browser.wait` (see _Walking_).  In
other words, it gets fired after all events are processed, with error
and browser as arguments.

Let's see that in action:

    // Now go to the shopping cart page and check that we have
    // three bodies there.
    browser.clickLink("View Cart", function(err, browser) {
      assert.equal(browser.querySelectorAll("#cart .body"), 3);
    });

To submit a form, use `pressButton`.  The first argument can be a CSS
selector, the button name (the value of the `name` argument) or the text
that shows on the button.  You can press any `BUTTON` element or `INPUT`
of type `submit`, `reset` or `button`.  The second argument is a
callback, just like `clickLink`.

Of course, before submitting a form, you'll need to fill it with values.
For text fields, use the `fill` function, which takes two arguments:
selector and the field value.  This time the selector can be a CSS
selector, the field name (its `name` attribute), or the text that shows
on the label associated with that field.

Zombie.js supports text fields, password fields, text areas, and also
the new HTML 5 fields types like email, search and url.

The `fill` function returns a reference to the browser, so you can chain
several functions together.  Its sibling functions `check` and `uncheck`
(for check boxes), `choose` (for radio buttons) and `select` (for drop
downs) work the same way.

Let's combine all of that into one example:

    // Fill in the form and submit.
    browser.
      fill("Your Name", "Arm Biter").
      fill("Profession", "Living dead").
      select("Born", "1968")
      uncheck("Send me the newsletter").
      pressButton("Sign me up", function(err, browser) {
        // Make sure we got redirected to thank you page.
        assert.equal(browser.location, "http://localhost:3003/thankyou");
      });


## Browser API

### Browser.visit(url, callback)

Shortcut for creating new browser and calling `browser.visit` on it.

### browser.body : Element

Returns the body Element of the current document.

### browser.check(field) : this
 
Checks a checkbox.

### browser.choose(field) : this

Selects a radio box option.

### browser.clickLink(selector, callback)
 
Clicks on a link. Clicking on a link can trigger other events, load new page,
etc: use a callback to be notified of completion.  Finds link by text content
or selector.

### browser.clock

The current system clock according to the browser (see also `browser.now`).

### browser.cookies(domain, path?) : Cookies

Returns all the cookies for this domain/path. Path defaults to "/".

### browser.debug(boolean, function?)

Call with `true`/`false` to turn debugging on/off.  Call with flag and
function to turn debugging on/off only for duration of that function
call.

### browser.debug(arguments)
### browser.debug(function)

Call with multiple arguments to spit them out to the console when
debugging enabled (same as `console.log`).  Call with function to spit
out the result of that function call when debugging enabled.

### browser.document : Document

Returns the main window's document. Only valid after opening a document (see `browser.open`).

### browser.dump

Dump a lot of information about the browser state to the console.

### browser.fill(field, value) : this

Fill in a field: input field or text area.

### browser.fire(name, target, calback?)

Fire a DOM event.  You can use this to simulate a DOM event, e.g. clicking a
link.  These events will bubble up and can be cancelled.  With a callback, this
function will call `wait`.

### browser.html(selector?, context?) : String

Returns the HTML contents of the selected elements.

### browser.lastError : Object

Returns the last error received by this browser in lieu of response.

### browser.lastRequest : Object

Returns the last request sent by this browser.

### browser.lastResponse : Object
 
Returns the last response received by this browser.

### browser.localStorage(host) : Storage
    
Returns local Storage based on the document origin (hostname/port).

### browser.location : Location

Return the location of the current document (same as `window.location.href`).

### browser.location = url

Changes document location, loads new document if necessary (same as setting
`window.location`).

### browser.now : Date

The current system time according to the browser (see also `browser.clock`).

### browser.open() : Window
 
Open new browser window.

### browser.pressButton(name, callback)
 
Press a button (button element or input of type `submit`).  Typically this will
submit the form.  Use the callback to wait for the from submission, page to
load and all events run their course.

### browser.querySelector(selector) : Element

Select a single element (first match) and return it.

### browser.querySelectorAll(selector) : NodeList

Select multiple elements and return a static node list.

### browser.select(field, value) : this
 
Selects an option.

### browser.sessionStorage(host) : Storage

Returns session Storage based on the document origin (hostname/port).

### browser.text(selector, context?) : String

Returns the text contents of the selected elements.

### browser.uncheck(field) : this

Unchecks a checkbox.

### browser.visit(url, callback)

Loads document from the specified URL, processes events and calls the callback.

### browser.wait(terminator, callback)

Process all events from the queue.  This includes resource loading, XHR
requests, timeout and interval timers.  Calls the callback when done.

The terminator is optional and can be one of:
* `null`, missing -- process all events
* Number -- process that number of events
* Function -- called after each event, returns false to stop processing

### browser.window : Window

Returns the main window.

### Event: 'drain'
`function (browser) { }`

Emitted whenever the event queue goes back to empty.

### Event: 'loaded'
`function (browser) { }`

Emitted whenever new page loaded.  This event is emitted before `DOMContentLoaded`.

### Event: 'error'
`function (error) { }`

Emitted if an error occurred loading a page or submitting a form.


## Readiness

Zombie.js supports the following:

- HTML parsing (documents must be valid, though)
- [DOM Level 3](http://www.w3.org/DOM/DOMTR) implementation
- HTML5 form fields (`search`, `url`, etc)
- C33 Selectors with [some extensions](http://sizzlejs.com/)
- Cookies and [Web Storage](http://dev.w3.org/html5/webstorage/)
- `XMLHttpRequest`
- `setTimeout`/`setInterval` and messing with the system clock
- `pushState` and the `popstate` event


## The Guts

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


## Giving Back

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

zombie-troubleshoot

[Troubleshooting](troubleshoot.html)

[Changelog](changelog.html)

[DOM API](http://www.w3.org/DOM/DOMTR)

[Sizzle.js](http://sizzlejs.com/)

[Vows](http://vowsjs.org/)
