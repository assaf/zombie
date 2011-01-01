zombie.js-api(7) -- The Zombie API
==================================


## The Browser

### new zombie.Browser(options?) : Browser

Creates and returns a new browser.  A browser maintains state across
requests: history, cookies, HTML 5 local and session stroage.  A browser
has a main window, and typically a document loaded into that window.

You can pass options when initializing a new browser, or set them on an
existing browser instance.  For example:

    browser = new zombie.Browser({ debug: true })
    browser.runScripts = false

### Browser Options

You can use the following options:

- `debug` -- True to have Zombie report what it's doing. Defaults to
  false.
- `runScripts` -- Run scripts included in or loaded from the page.
  Defaults to true.
- `userAgent` -- The User-Agent string to send to the server.

### Browser.visit(url, callback)
### Browser.visit(url, options, callback)

Shortcut for creating new browser and calling `browser.visit` on it.  If
the second argument are options, initializes the browser with these
options.  See *Navigation* below for more information about the `visit`
method.

### browser.open() : Window
 
Opens a new browser window.

### browser.window : Window

Returns the main window.  A browser always has one window open.


## Document Content

You can inspect the document content using the [DOM
API](http://www.w3.org/DOM/DOMTR) traversal methods or the [DOM Selector
API](http://www.w3.org/TR/selectors-api/).

To find an element with ID "item-23":

  var item = document.getElementById("item-32");

For example, to find out the first input field with the name "email":

  var field = document.querySelector(":input[name=email]");

To find out all the even rows in a table:

  var rows = table.querySelectorAll("tr:even");

CSS selectors support is provied by
[Sizzle.js](https://github.com/jeresig/sizzle/wiki), the same engine
used by jQuery.  You're probably familiar with it, if not, check the
[list of supported selectors](selectors.html).

### browser.body : Element

Returns the body element of the current document.

### browser.css(selector, context?) => NodeList

Evaluates the CSS selector against the document (or context node) and
return a node list.  Shortcut for `document.querySelectorAll`.

### browser.document : Document

Returns the main window's document.  Only valid after opening a document
(see `browser.visit`).

### browser.evaluate(expr) : Object

Evaluates a JavaScript expression in the context of the current window
and returns the result.  For example:

    browser.evaluate("document.title");

### browser.html(selector?, context?) : String

Returns the HTML contents of the selected elements.

With no arguments returns the HTML contents of the document.  This is
one way to find out what the page looks like after executing a bunch of
JavaScript.

With one argument, the first argument is a CSS selector evaluated
against the document body.  With two arguments, the CSS selector is
evaluated against the element given as the context.

For example:

    console.log(browser.html("#main"));

### browser.querySelector(selector) : Element

Select a single element (first match) and return it.  This is a shortcut
that calls `querySelector` on the document.

### browser.querySelectorAll(selector) : NodeList

Select multiple elements and return a static node list.  This is a
shortcut that calls `querySelectorAll` on the document.

### browser.text(selector, context?) : String

Returns the text contents of the selected elements.

With one argument, the first argument is a CSS selector evaluated
against the document body.  With two arguments, the CSS selector is
evaluated against the element given as the context.

For example:

    console.log(browser.text("title"));

### browser.xpath(expression, context?) => XPathResult

Evaluates the XPath expression against the document (or context node)
and return the XPath result.  Shortcut for `document.evaluate`.


## Navigation

Zombie.js loads pages asynchronously.  In addition, a page may require
loading additional resources (such as JavaScript files) and executing
various event handlers (e.g. `jQuery.onready`).

For that reason, navigating to a new page doesn't land you immediately
on that page: you have to wait for the browser to complete processing of
all events.  You can do that by calling `browser.wait` or passing a
callback to methods like `visit` and `clickLink.`

### browser.clickLink(selector, callback)
 
Clicks on a link.  The first argument is the link text or CSS selector.
Second argument is a callback, invoked after all events are allowed to
run their course.

Zombie.js fires a `click` event and has a default event handler that
will to the link's `href` value, just like a browser would.  However,
event handlers may intercept the event and do other things, just like a
real browser.

For example:

    browser.clickLink("View Cart", function(err, browser) {
      assert.equal(browser.querySelectorAll("#cart .body"), 3);
    });


### browser.link(selector) : Element

Finds and returns a link (`A`) element.  You can use a CSS selector or
find a link by its text contents (case sensitive, but ignores
leading/trailing spaces). 

### browser.location : Location

Return the location of the current document (same as `window.location`).

### browser.location = url

Changes document location, loading a new document if necessary (same as setting
`window.location`).  This will also work if you just need to change the
hash (Zombie.js will fire a `hashchange` event), for example:

    browser.location = "#bang";
    browser.wait(function(err, browser) {
      // Fired hashchange event and did something cool.
      ...
    });

### browser.visit(url, callback)
### browser.visit(url, options, callback)

Loads document from the specified URL, processes all events in the
queue, and finally invokes the callback.

In the second form, sets the options for the duration of the request,
and resets before passing control to the callback.  For example:

    browser.visit("http://localhost:3000", { debug: true },
      function(err, browser) {
        if (err)
          throw(err.message);
        console.log("The page:", browser.html());
      }
    );
    

## Forms

Methods for interacting with form controls (e.g. `fill`, `check`) take a
first argument that tries to identify the form control using a variety
of approaches.  You can always select the form control using an
appropriate [CSS selector](selectors.html).

Zombie.js can also identify form controls using their name (the value of
the `name` attribute) or using the text of the label associated with
that control.  In both case, the comparison is case sensitive, but to
work flawlessly, ignores leading/trailing whitespaces when looking at
labels.

If there are no event handlers, Zombie.js will submit the form just like
a browser would, process the response (including any redirects) and
transfer control to the callback function when done.

If there are event handlers, they will all be run before transferring
control to the callback function.  Zombie.js can even support jQuery
live event handlers.

### browser.check(field) : this
 
Checks a checkbox.  The argument can be the field name, label text or a
CSS selector.

Returns itself.

### browser.choose(field) : this

Selects a radio box option.  The argument can be the field name, label
text or a CSS selector.

Returns itself.

### browser.field(selector) : Element

Find and return an input field (`INPUT`, `TEXTAREA` or `SELECT`) based
on a CSS selector, field name (its `name` attribute) or the text value
of a label associated with that field (case sensitive, but ignores
leading/trailing spaces).

### browser.fill(field, value) : this

Fill in a field: input field or text area.  The first argument can be
the field name, label text or a CSS selector.  The second argument is
the field value.

For example:

    browser.fill("Name", "ArmBiter").fill("Password", "Brains...")

Returns itself.

### browser.button(selector) : Element

Finds a button using CSS selector, button name or button text (`BUTTON`
or `INPUT` element).

### browser.pressButton(selector, callback)
 
Press a button.  Typically this will submit the form, but may also reset
the form or simulate a click, depending on the button type.

The first argument is either the button name, text value or CSS
selector.  Second argument is a callback, invoked after the button is
pressed, form submitted and all events allowed to run their course.

For example:

    browser.fill("email", "zombie@underworld.dead").
      pressButton("Sign me Up", function(err) {
        // All signed up, now what?
      });

Returns nothing.

### browser.select(field, value) : this
 
Selects an option.  The first argument can be the field name, label text
or a CSS selector.  The second value is the option to select, by value
or label.

For example:

    browser.select("Currency", "brain$")

Returns itself.

### browser.uncheck(field) : this

Unchecks a checkbox.  The argument can be the field name, label text or
a CSS selector.


## State Management

The browser maintains state as you navigate from one page to another.
Zombie.js supports both [cookies](http://www.ietf.org/rfc/rfc2109.txt)
and HTML5 [Web Storage](http://dev.w3.org/html5/webstorage/).

Note that Web storage is specific to a host/port combination.  Cookie
storage is specific to a domain, typically a host, ignoring the port.

### browser.cookies(domain, path?) : Cookies

Returns all the cookies for this domain/path. Path defaults to "/".

For example:

    browser.cookies("localhost").set("session", "567");

The `Cookies` object has the methods `get(name)`, `set(name, value)`,
`remove(name)` and `dump()`.

The `set` method accepts a third argument which may include the options
`expires`, `maxAge` and `secure`.

### browser.localStorage(host) : Storage
    
Returns local Storage based on the document origin (hostname/port).

For example:

    browser.localStorage("localhost:3000").setItem("session", "567");

The `Storage` object has the methods `key(index)`, `getItem(name)`,
`setItem(name, value)`, `removeItem(name)`, `clear()` and `dump`.  It
also has the read-only property `length`.

### browser.sessionStorage(host) : Storage

Returns session Storage based on the document origin (hostname/port).
See `localStorage` above.


## Events

Since events may execute asynchronously (e.g. XHR requests, timers), the
browser maintains an event queue.  Occasionally you will need to let the
browser execute all the queued events before proceeding.  This is done
by calling `wait`, or one of the many methods that accept a callback.

In addition the browser is also an `EventEmitter`.  You can register
any number of event listeners to any of the emitted events.

### browser.clock

The current system clock according to the browser (see also `browser.now`).

### browser.now : Date

The current system time according to the browser (see also `browser.clock`).

### browser.fire(name, target, calback?)

Fires a DOM event.  You can use this to simulate a DOM event, e.g.
clicking a link or clicking the mouse.  These events will bubble up and
can be cancelled.

The first argument it the event name (e.g. `click`), the second argument
is the target element of the event.  With a callback, this method will
transfer control to the callback after running all events.

### browser.wait(callback)
### browser.wait(terminator, callback)

Process all events in the queue and calls the callback when done.

You can use the second form to pass control before processing all
events.  The terminator can be a number, in which case that many events
are processed.  It can be a function, which is called after each event;
processing stops when the function returns the value `false`.

### Event: 'drain'
`function (browser) { }`

Emitted whenever the event queue goes back to empty.

### Event: 'loaded'
`function (browser) { }`

Emitted whenever new page loaded.  This event is emitted before
`DOMContentLoaded`.

### Event: 'error'
`function (error) { }`

Emitted if an error occurred loading a page or submitting a form.


## Debugging

When trouble strikes, refer to these functions and the [troubleshooting
guide](troubleshoot.html).

### browser.dump()

Dump information to the console: Zombie version, current URL, history,
cookies, event loop, etc.  Useful for debugging and submitting error
reports.

### browser.lastError : Object

Returns the last error received by this browser in lieu of response.

### browser.lastRequest : Object

Returns the last request sent by this browser.

### browser.lastResponse : Object
 
Returns the last response received by this browser.

### browser.log(arguments)
### browser.log(function)

Call with multiple arguments to spit them out to the console when
debugging enabled (same as `console.log`).  Call with function to spit
out the result of that function call when debugging enabled.

### browser.viewInBrowser(name?)

Views the current document in a real Web browser.  Uses the default
system browser on OS X, BSD and Linux.  Probably errors on Windows.


## Notes

#### Callbacks

By convention most callback functions take two arguments.  If an error
occurred, the first argument is the error and the second argument is
`null`.  If everything went smoothly, the first argument is `null` and
the second argument is the relevant value (e.g. the brower, a window).


