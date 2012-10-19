zombie.js-api(7) -- The Zombie API
==================================


## The Browser

### new zombie.Browser(options?) : Browser

Creates and returns a new browser.  A browser maintains state across requests:
history, cookies, HTML 5 local and session storage.  A browser has a main
window, and typically a document loaded into that window.

You can pass options when initializing a new browser, for example:

    var Browser = require("zombie")

    var browser = new Browser({ debug: true })
    browser.runScripts = false

Or on existing browser for the duration of a page load:

    Browser.visit("http://localhost:3000/", { debug: true, runScripts: false },
                 function (e, browser, status) {
      ...
    });

You can also set options globally for all browsers to inherit:

    Browser.site = "http://localhost:3000"
    Browser.loadCSS = false


### Browser Options

You can use the following options:

- `debug` -- Have Zombie report what it's doing.  Defaults to true if
  environment variable `DEBUG` is set.
- `headers` -- Additional HTTP headers to be sent with each browser request.
- `loadCSS` -- Loads external stylesheets.  Defaults to true.
- `maxWait` -- Maximum wait time (when calling `visit`, `wait`, etc).  Defaults
  to 5 seconds.
- `maxRedirects` -- Tells the browser how many redirects to follow before aborting a request. Defaults to 5
- `proxy` -- Proxy URL.
- `runScripts` -- Run scripts included in or loaded from the page.  Defaults to
  true.
- `userAgent` -- The User-Agent string to send to the server.
- `silent` -- If true, supress all `console.log` output from scripts.  You can
  still view it with `window.console.output`.
- `site` -- Base URL for all requests.  If set, you can call `visit` with
  relative URL.
- `waitFor` -- Tells `wait` function how long to wait (in milliseconds) while
  timers fire.  Defaults to 0.5 seconds.

The proxy URL specifies the host and port of the proxy.  It also supports HTTP
Basic authentication, for example:

    browser.proxy = "http://user:password@proxy:8080"


### browser.authenticate(host) : Credentials

Use this to set the authentication credentials for the given host
(hostname:port).  Returns a credentials object.

Call with no arguments to set the default authentication credentials (apply to
any host that doesn't have specific credentials).

For example:

    // HTTP Basic takes user and password
    browser.authenticate().basic("me", "secret")
    // OAuth 2.0 Bearer takes an access token
    browser.authenticate("example.com:443").bearer("12345")
    // Show the authentication credentials in use
    console.log(browser.authenticate().token)

### browser.close()

Close all windows, dispose of all resources. You want to call this if you're
running out of memory.

### browser.error : Error

Returns the last error reported while loading this window.

### browser.errors : Array

Returns all errors reported while loading this window.

### browser.open() : Window
 
Opens a new browser window.

### browser.visit(url, callback)
### browser.visit(url, options, callback)

Shortcut for creating new browser and calling `browser.visit` on it.  If the
second argument are options, initializes the browser with these options.  See
*Navigation* below for more information about the `visit` method.

### browser.window : Window

Returns the main window.  A browser always has one window open.

### browser.windows : Windows

Returns access to the collection of open windows.  You can use this to select
specific window, close current window, etc.


## Document Content

You can inspect the document content using the [DOM
API](http://www.w3.org/DOM/DOMTR) traversal methods or the [DOM Selector
API](http://www.w3.org/TR/selectors-api/).

To find an element with ID "item-23":

    var item = document.getElementById("item-23");

For example, to find out the first input field with the name "email":

    var field = document.querySelector(":input[name=email]");

To find out all the even rows in a table:

    var rows = table.querySelectorAll("tr:even");

CSS selectors support is provied by [Sizzle.js](http://sizzlejs.com/), the same
engine used by jQuery.  You're probably familiar with it, if not, check the
[list of supported selectors](selectors).

### browser.body : Element

Returns the body element of the current document.

### browser.document : Document

Returns the main window's document.  Only valid after opening a document (see
`browser.visit`).

### browser.evaluate(expr) : Object

Evaluates a JavaScript expression in the context of the current window and
returns the result.  For example:

    browser.evaluate("document.title");

### browser.html(selector?, context?) : String

Returns the HTML contents of the selected elements.

With no arguments returns the HTML contents of the document.  This is one way to
find out what the page looks like after executing a bunch of JavaScript.

With one argument, the first argument is a CSS selector evaluated against the
document body.  With two arguments, the CSS selector is evaluated against the
element given as the context.

For example:

    console.log(browser.html("#main"));

### browser.queryAll(selector, context?) : Array

Evaluates the CSS selector against the document (or context node) and return
array of nodes.  (Unlike `document.querySelectorAll` that returns a node list).

### browser.query(selector, context?) : Element

Evaluates the CSS selector against the document (or context node) and return an
element.

### browser.text(selector, context?) : String

Returns the text contents of the selected elements.

With one argument, the first argument is a CSS selector evaluated against the
document body.  With two arguments, the CSS selector is evaluated against the
element given as the context.

For example:

    console.log(browser.text("title"));

### browser.xpath(expression, context?) : XPathResult

Evaluates the XPath expression against the document (or context node) and return
the XPath result.  Shortcut for `document.evaluate`.


## Navigation

Zombie.js loads pages asynchronously.  In addition, a page may require loading
additional resources (such as JavaScript files) and executing various event
handlers (e.g. `jQuery.onready`).

For that reason, navigating to a new page doesn't land you immediately on that
page: you have to wait for the browser to complete processing of all events.
You can do that by calling `browser.wait`, passing a callback to methods like
`visit` and `clickLink`, or using promises.

### browser.back(callback)

Navigate to the previous page in history.

### browser.clickLink(selector, callback)
 
Clicks on a link.  The first argument is the link text or CSS selector.

Zombie.js fires a `click` event and has a default event handler that will to the
link's `href` value, just like a browser would.  However, event handlers may
intercept the event and do other things, just like a real browser.

For example:

    browser.clickLink("View Cart", function() {
      assert.lengthOf(browser.queryAll("#cart .body"), 3);
    });

Just like `wait`, this function either takes a callback or returns a promise,
and will wait for all events to fire.

### browser.history : History

Returns the history of the current window (same as `window.history`).

### browser.link(selector) : Element

Finds and returns a link (`A`) element.  You can use a CSS selector or find a
link by its text contents (case sensitive, but ignores leading/trailing spaces). 

### browser.location : Location

Return the location of the current document (same as `window.location`).

### browser.location = url

Changes document location, loading a new document if necessary (same as setting
`window.location`).  This will also work if you just need to change the hash
(Zombie.js will fire a `hashchange` event), for example:

    browser.location = "#bang";
    browser.wait(function(e, browser) {
      // Fired hashchange event and did something cool.
      ...
    });

### browser.reload(callback)

Reloads the current page.

### browser.statusCode : Number

Returns the status code returned for this page request (200, 303, etc).

### browser.success : Boolean

Returns true if the status code is 2xx.

### browser.load(html, callback)

Loads this HTML, processes events and calls the callback.

Without a callback, returns a promise.

### browser.visit(url, callback)
### browser.visit(url, options, callback)

Loads document from the specified URL, processes all events in the queue, and
finally invokes the callback.

In the second form, sets the options for the duration of the request, and resets
before passing control to the callback.  For example:

    browser.visit("http://localhost:3000", { debug: true },
      function(e, browser) {
        console.log("The page:", browser.html());
      }
    );

If the last argument is a callback, it will be called with either error, or with
null and browser object.

Otherwise, returns a promise object you can use to wait for the page to load and
all events to fire.  For example:

    browser.visit("http://localhost:3000").
      then(function() {
        console.log("The page:", browser.html());
      }).
      fail(function(error) {
        console.log("Not good:", error)
      })

### browser.redirected : Boolean

Returns true if the page request followed a redirect.
    
### browser.url : String

Return the URL of the current document (same as `document.URL`).


## Forms

Methods for interacting with form controls (e.g. `fill`, `check`) take a first
argument that tries to identify the form control using a variety of approaches.
You can always select the form control using an appropriate [CSS
selector](selectors), or pass the element itself.

Zombie.js can also identify form controls using their name (the value of the
`name` attribute) or using the text of the label associated with that control.
In both case, the comparison is case sensitive, but to work flawlessly, ignores
leading/trailing whitespaces when looking at labels.

If there are no event handlers, Zombie.js will submit the form just like a
browser would, process the response (including any redirects) and transfer
control to the callback function when done.

If there are event handlers, they will all be run before transferring control to
the callback function.  Zombie.js can even support jQuery live event handlers.

### browser.attach(selector, filename, callback) : this

Attaches a file to the specified input field.  The second argument is the file
name (you cannot attach streams).

Returns this so you can chain multiple methods.

### browser.check(field, callback) : this
 
Checks a checkbox.  The argument can be the field name, label text or a CSS
selector.

Returns this so you can chain multiple methods.

### browser.choose(field, callback) : this

Selects a radio box option.  The argument can be the field name, label text or a
CSS selector.

Returns this so you can chain multiple methods.

### browser.field(selector) : Element

Find and return an input field (`INPUT`, `TEXTAREA` or `SELECT`) based on a CSS
selector, field name (its `name` attribute) or the text value of a label
associated with that field (case sensitive, but ignores leading/trailing
spaces).

### browser.fill(field, value, callback) : this

Fill in a field: input field or text area.  The first argument can be the field
name, label text or a CSS selector.  The second argument is the field value.

For example:

    browser.fill("Name", "ArmBiter").fill("Password", "Brains...")

### browser.button(selector) : Element

Finds a button using CSS selector, button name or button text (`BUTTON` or
`INPUT` element).

### browser.pressButton(selector, callback)
 
Press a button.  Typically this will submit the form, but may also reset the
form or simulate a click, depending on the button type.

The first argument is either the button name, text value or CSS selector.
Second argument is a callback, invoked after the button is pressed, form
submitted and all events allowed to run their course.

For example:

    browser.fill("email", "zombie@underworld.dead").
      pressButton("Sign me Up", function() {
        // All signed up, now what?
      });

Returns nothing.

### browser.select(field, value, callback) : this
 
Selects an option.  The first argument can be the field name, label text or a
CSS selector.  The second value is the option to select, by value or label.

For example:

    browser.select("Currency", "brains")

See also `selectOption`.

Returns this so you can chain multiple methods.

### browser.selectOption(option, callback) : this

Selects the option (an `OPTION` element).

Returns this so you can chain multiple methods.

### browser.uncheck(field, callback) : this

Unchecks a checkbox.  The argument can be the field name, label text or a CSS
selector.

Returns this so you can chain multiple methods.

### browser.unselect(field, value, callback) : this
 
Unselects an option.  The first argument can be the field name, label text or a
CSS selector.  The second value is the option to unselect, by value or label.

You can use this (or `unselectOption`) when dealing with multiple selection.

Returns this so you can chain multiple methods.

### browser.unselectOption(option, callback) : this

Unselects the option (an `OPTION` element).

Returns this so you can chain multiple methods.


### browser.focused : element

Returns the element in focus.


## State Management

The browser maintains state as you navigate from one page to another.  Zombie.js
supports both [cookies](http://www.ietf.org/rfc/rfc2109.txt) and HTML5 [Web
Storage](http://dev.w3.org/html5/webstorage/).

Note that Web storage is specific to a host/port combination.  Cookie storage is
specific to a domain, typically a host, ignoring the port.

### browser.cookies(domain?, path?) : Cookies

Returns all the cookies for this domain/path.  Without domain, uses the hostname
of the currently loaded page.  Without path, uses the pathname of the currently
loaded page.

For example:

    browser.cookies().set("session", "123");
    browser.cookies("host.example.com", "/path").set("onlyhere", "567");

The `Cookies` object has the methods `all()`, `clear()`, `get(name)`, `set(name,
value)`, `remove(name)` and `dump()`.

The `set` method accepts a third argument which may include the options
`expires`, `maxAge`, `httpOnly` and `secure`.

### browser.fork() : Browser

Return a new browser using a snapshot of this browser's state.  This method
clones the forked browser's cookies, history and storage.  The two browsers are
independent, actions you perform in one browser do not affect the other.

Particularly useful for constructing a state (e.g.  sign in, add items to a
shopping cart) and using that as the base for multiple tests, and for running
parallel tests in Vows.

### browser.loadCookies(String)

Load cookies from a text string (e.g. previously created using
`browser.saveCookies`.

### browser.loadHistory(String)

Load history from a text string (e.g. previously created using
`browser.saveHistory`.

### browser.loadStorage(String)

Load local/session stroage from a text string (e.g. previously created using
`browser.saveStorage`.

### browser.localStorage(host) : Storage
    
Returns local Storage based on the document origin (hostname/port).

For example:

    browser.localStorage("localhost:3000").setItem("session", "567");

The `Storage` object has the methods `key(index)`, `getItem(name)`,
`setItem(name, value)`, `removeItem(name)`, `clear()` and `dump`.  It also has
the read-only property `length`.

### browser.saveCookies() : String

Save cookies to a text string.  You can use this to load them back later on
using `browser.loadCookies`.

### browser.saveHistory() : String

Save history to a text string.  You can use this to load the data later on using
`browser.loadHistory`.

### browser.saveStorage() : String

Save local/session storage to a text string.  You can use this to load the data
later on using `browser.loadStorage`.

### browser.sessionStorage(host) : Storage

Returns session Storage based on the document origin (hostname/port).  See
`localStorage` above.


## Interaction
 
### browser.onalert(fn)

Called by `window.alert` with the message.  If you just want to know if an alert
was shown, you can also use `prompted` (see below).

### browser.onconfirm(question, response)
### browser.onconfirm(fn)

The first form specifies a canned response to return when `window.confirm` is
called with that question.  The second form will call the function with the
question and use the respone of the first function to return a value (true or
false).

The response to the question can be true or false, so all canned responses are
converted to either value.  If no response available, returns false.

For example:

    browser.onconfirm("Are you sure?", true)

### browser.onprompt(message, response)
### browser.onprompt(fn)

The first form specifies a canned response to return when `window.prompt` is
called with that message.  The second form will call the function with the
message and default value and use the response of the first function to return a
value or false.

The response to a prompt can be any value (converted to a string), false to
indicate the user cancelled the prompt (returning null), or nothing to have the
prompt return the default value or an empty string.

For example:

    browser.onprompt(function(message) { return Math.random() })

### browser.prompted(message) : boolean

Returns true if user was prompted with that message by a previous call to
`window.alert`, `window.confirm` or `window.prompt`.


## Events

Since events may execute asynchronously (e.g. XHR requests, timers), the browser
maintains an event queue.  Occasionally you will need to let the browser execute
all the queued events before proceeding.  This is done by calling `wait`, or one
of the many methods that accept a callback.

In addition the browser is also an `EventEmitter`.  You can register any number
of event listeners to any of the emitted events.

### browser.fire(name, target, calback?)

Fires a DOM event.  You can use this to simulate a DOM event, e.g. clicking a
link or clicking the mouse.  These events will bubble up and can be cancelled.

The first argument it the event name (e.g. `click`), the second argument is the
target element of the event.

Just like `wait`, this method either takes a callback or returns a promise (and
will wait for events to fire).

### browser.wait(callback?)
### browser.wait(duration, callback?)
### browser.wait(done, callback?)

Waits for the browser to complete loading resources and processing JavaScript
events.

The browser will wait for resources to load (scripts, iframes, etc), XHR
requests to complete, DOM events to fire and timers (timeout and interval).  But
it can't wait forever, especially not for timers that may fire repeatedly (e.g.
checking page state, long polling).

There are two mechanisms to determine completion of processing.  You can tell
the browser to give up after certain time by passing the duration as first
argument, or by setting the browser option `waitFor`.  The default value is 0.5
seconds.

You can also tell the browser to wait for something to happen on the page by
passing a function as the first argument.  That function is called repeatedly
with the window object, and should return true (or any value equal to true) when
it's time to pass control back to the application.

For example:

    // Wait until map is loaded
    function mapLoaded(window) {
      return window.document.querySelector("#map");
    }
    browser.wait(mapLoaded, function() {
      // Page has a #map element now

    })

Using promises instead of a callback and duration function is tricky: you must
call `wait` with two arguments, the last one being `null`.

Even with completion function, the browser won't wait forever.  It will complete
as soon as it determines there are no more events to wait for, or after 5
seconds of waiting (you can change this with `maxWait` option).

If you call `wait` with a callback as the last argument, it will be notified
once on completion or when the first error occurs.  If you call `wait` without a
callback, it returns a promise that you can wait on.

### Event: 'done'
`function (browser) { }`

Emitted whenever the event queue goes back to empty.

### Event: 'error'
`function (error) { }`

Emitted if an error occurred loading a page or submitting a form.

### Event: 'loaded'
`function (browser) { }`

Emitted whenever new page loaded.  This event is emitted before
`DOMContentLoaded`.


## Debugging

When trouble strikes, refer to these functions and the [troubleshooting
guide](troubleshoot).

### browser.dump()

Dump information to the console: Zombie version, current URL, history, cookies,
event loop, etc.  Useful for debugging and submitting error reports.

### browser.lastError : Object

Returns the last error received by this browser in lieu of response.

### browser.lastRequest : Object

Returns the last request sent by this browser.

### browser.lastResponse : Object
 
Returns the last response received by this browser.

### browser.log(arguments)
### browser.log(function)

Call with multiple arguments to spit them out to the console when debugging
enabled (same as `console.log`).  Call with function to spit out the result of
that function call when debugging enabled.

### browser.resources : Object

Returns a list of resources loaded by the browser.

### browser.viewInBrowser(name?)

Views the current document in a real Web browser.  Uses the default system
browser on OS X, BSD and Linux.  Probably errors on Windows.


## Windows

You can use `browser.windows` to manage currently open windows.  Anything you
tell the browser to do happens in the `current` window, which you can change
using `select`.  Use `browser.open` to open a new window.

### windows.all(): Array

Returns all open windows.

### windows.close(window)

Closes the specified window.  With no arguments, closes the last window.
If closing the current window, switches to the previously opened window.

### windows.count : number

Number of open windows

### windows.current : Window

Returns the current window.  All operations on the browser are sent to this
window.

### windows.get(name_or_index) : Window

Returns specific window by its name or position (e.g. "foo" returns the window
named "foo", while 1 returns the second window)

### windows.select(window) : Window

Selects specified window as the current window.  You can pass the window name,
position, or actual `Window` object.

