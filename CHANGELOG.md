zombie.js-changelog(7) -- Changelog
===================================


## Version 1.4.1 2012-08-22

Fixed another timer edge case.

    550 tests
    14.5 sec to complete


## Version 1.4.0 2012-08-22

Support for browser custom headers ():

  browser.headers =
    "Accept-Language": "da, en-gb"

`browser.fork()` now copies browser options (Jakub Kulhan).

Fixed `window.close()` to properly dispose of the context, and added
`browser.close()` to properly close all windows and cleanup.  If you're running
into memory issues, use either method.

Share the same location instance between history stack entries (David Stendardi)

Do not down-case file: URLs.

Implemented `Node.contains` (Dave Dopson).

Setting `element.style.width` now reflected in value of `element.clientWidth`
and `element.offsetWidth` (and same for height).

Upgraded dependencies, tested with Node 0.8.6, jQuery 1.8.0, require.js 2.0.6.

Fail if Contextify module not available.

Fixed edge case where timers may fire after `browser.wait` returns.

    550 tests
    14.5 sec to complete


## Version 1.3.1 2012-06-05

The `id`, `name` and `value` properties should be empty strings if the
corresponding attribute is not set.

    537 tests
    13.0 sec to complete


## Version 1.3.0 2012-06-05

Note that `browser.text` now trims and strips consecutive whitespace.

Added maximum waiting period with the `maxWait` browser option, which defaults
to 5 seconds.

You can set `maxWait` and `wait` duration as number of milliseconds or textual
value like "5s", "1m", etc.

Fixed `a.href` to not break when missing `href` attribute.

Fixed JS execution bug that messes with require.js.

Fixed failing to create empty document on HTTP error.

    531 tests
    12.8 sec to complete


## Version 1.2.0 2012-05-28

Added `browser.load` for loading HTML instead of hitting a URL.

Allow `browser.select` to use the option text.

Reload document when forking browser.

Set `accept-encoding` to "identity".

`JSON.parse` now respects `Array.prototype`.

Implemented `window.resizeBy` and `window.resizeTo`.

If DOM attribute is not set, `getAttribute` will return `null` just like any
browser (though the spec insists on empty string).

Fix all file loading (document and resources) to use same code path.

    531 tests
    12.5 sec to complete


## Version 1.1.7 2012-05-27

Create DOM document after Web page has loaded.  If you want to set document
location and wait for document to load, so this:

  browser.location = url;
  browser.on("loaded", function() {
    // Called after document has loaded
    ...
  })

Remove 'Content Type' and 'Content Length' on redirect (re-fixed.)

    513 tests
    12.2 sec to complete


## Version 1.1.6 2012-05-26

Fire `focus` and `blur` events when filling fields, selecting fields, pressing
button and switching windows.

Both `focus` and `blur` methods now work and you can get the `activeElement`.

Tweak to in-line script processing to fix a problem no one reported.

    513 tests
    12.3 sec to complete


## Version 1.1.5 2012-05-24

The `wait` function (and its derivatives) now return most recent error in
callback.

To use promises and duration function, call `wait` with two arguments, second
one being `null`.

Workaround for the tricky `getElementById("foo").querySelector("#foo .bar")`
behavior that JSDOM doesn't get quite right.

    500 tests
    12.3 sec to complete


## Version 1.1.4 2012-05-22

Make sure `wait` callback doesn't get the wrong `this`.

    496 tests
    11.5 sec to complete


## Version 1.1.3 2012-05-22

Fixed setting cookie on redirect to different domain.

Fixed iframe doesn't retain value of src attribute.

Fixed window.close property not set (Jerome Gravel-Niquet).

Added documentation and tests for promises.

    496 tests
    11.9 sec to complete


## Version 1.1.2 2012-05-16

Trim stack trace at call to `contextify.run`.  Also, if you upgrade, Contextify
no longer dumps error messages to stderr.

    489 tests
    11.8 sec to complete


## Version 1.1.1 2012-05-16

Fixes `visit` and `wait` silencing any exceptions thrown during the callback's
execution.

Added empty `navigator.plugins`.

Added `atob` and `btoa`.

    489 tests
    12.0 sec to complete


## Version 1.1.0 2012-05-13

Fixed `onload` event not firing on window.

Added `navigator.cookieEnabled` and `navigator.vendor`.

Added empty `Accept-Encoding` header since there's no gzip/compress support at
the moment.

Fixed `Browser` default settings.

Upgraded to HTML5 0.3.8.

    487 tests
    11.8 sec to complete


## Version 1.0.0 2012-05-10

Yes, that is right, Zombie now supports promises.  Like this:

    browser.visit("http://localhost:3000/").
      then(function() {
        assert.equal(browser.text("H1"), "Deferred zombies");
        // Chaining works by returning a promise here
        return browser.clickLink("Hit me");
      }).
      then(function() {
        assert.equal(browser.text("H1"), "Ouch");
      });

A new way to set authentication credentials so they can be applied to specific
host (e.g. HTTP Basic one host, OAuth Bearer another).  Like this:

    // HTTP Basic takes user and password
    browser.authenticate().basic("me", "secret")
    // OAuth 2.0 Bearer takes an access token
    browser.authenticate("example.com:443").bearer("12345")
    // Show the authentication credentials in use
    console.log(browser.authenticate().token)

Successfully testing Facebook Connect using Zombie (see
`test/facebook_connect_test.coffee`).

    487 tests
    12.1 sec to complete


## Version 0.13.14 2012-05-09

Changed browser option `windowName` to just `name.`

Setting browser option to `undefined` no longer resets it to default (that was a
stupid idea).

Support for opening link in specified target (named window, `_self`, `_parent`, `_top` or
`_blank`).

Fixed Zombie retaining multiple values for the same cookie (domain/path/key).

    485 tests
    11.9 sec to complete


## Version 0.13.13 2012-05-09

Should be `windows.select` not `windows.switch`.

    462 tests
    11.4 sec to complete


## Version 0.13.12 2012-05-09

Cleaned up and documented `browser.windows`.

Brought back JSDOM offset patches, Google Maps fails badly without these.

    462 tests
    11.4 sec to complete


## Version 0.13.11 2012-05-08

Fix loading URL with document fragment remove document fragment from page
location.

    459 tests
    9.9 sec to complete


## Version 0.13.10 2012-05-07

Fixed basic/token authentication working for pages but not resources like JS,
CSS (David Newell).

Old-style event handlers (onclick, onsubmit, etc) now have access to event
through `window.event`.

Old-style event handlers can return false to prevent default behavior.

Added `window.Event` and its siblings `UIEvent`, `MouseEvent`, `MutationEvent`
and `StorageEvent`.

    457 tests
    10.2 sec to complete


## Version 0.13.9 2012-05-07

Make sure you can `window.frames[name].postMessage`.

    453 tests
    9.9 sec to complete


## Version 0.13.8 2012-05-04

Redirection is now handled by Zombie instead of Request, set cookies to the
right domain.

Run without Coffee-Script.

    453 tests
    9.7 sec to complete


## Version 0.13.7 2012-05-03

Added support for `postMessage`.

Added support for `window.open()` and working with more than one window at a
time (`browser.windows`).

When following redirect with `#` in it, fire the `hashchange` event.

IFrame window name based on element's `name` attribute.

Fixed IFrame document and window to include Zombie enhancements.

Zombie can now show FB Connect form.

    453 tests
    9.8 sec to complete


## Version 0.13.6 2012-05-02

You can now set document location to `javascript:expression` and it will
evaluate that expression.

    440 tests
    9.6 sec to complete


## Version 0.13.5 2012-05-02

Switched default HTML parser back to the more forgiving
[HTML5](https://github.com/aredridel/html5):

- Supports scripts with CDATA
- Supports tag soups
- Preserve order of execution between in-line and loaded JS code
- Support `document.write`

Fix `textContent` of elements that have comments in them to not exclude the
comment text .

    438 tests
    9.7 sec to complete


## Version 0.13.4 2012-05-01

Upgraded to JSDOM 0.2.14.  This includes an upgrade to Contextify which fixes an
edge case with JS scoping.  It also translates to 10% faster tests (On My
Machine).

But HTML processing is a bit more picky right now.

Methods like `visit` now pass error to the callback if they fail to load or
parse the page.  JavaScript execution errors are handled separately.

    436 tests
    8.0 sec to complete


## Version 0.13.3 2012-04-30

Fixed failing to redirect after POST request (Vincent P).

    426 tests
    8.8 sec to complete


## Version 0.13.2 2012-04-26

Fixed iframes not loading properly of firing `onload` event when setting `src`
attribute.

    426 tests
    9.6 sec to complete


## Version 0.13.1 2012-04-26

Switched from testing with Vows to testing with Mocha.  Tests now running
sequentially.

Fixed a couple of issues with cookies, also switched to a better implementation,
see [Tough Cookie](https://github.com/goinstant/node-cookie)

Zombie now submits empty text fields and checked checkboxes with no value.

Support for script type="text/coffeescript" (audreyt).

    425 tests
    10.0 sec to complete


## Version 0.13.0 2012-04-25

Now requires Node 0.6.x or later.  Also upgraded to CoffeeScript 1.3.1, which
helped find a couple of skipped tests.

Added support for proxies by using the excellent [Request
module](https://github.com/mikeal/request)

Added File object in browser (Ian Young)

Added support for EventSource (see [Server-Sent Events](http://dev.w3.org/html5/eventsource/))


## Version 0.12.15 2012-02-23

Maintenance release: JSDOM 0.2.11/12 is broken, fixing to 0.2.10 (Mike Swift)


## Version 0.12.14 2012-02-07

Fix redirect not passing the same headers again.

    412 tests
    6.4 sec to complete


## Version 0.12.13 2012-01-18

`Browser.fire` takes no options (that was an undocumented argument), and always fires events that bubble and can be
cancelled.

Clicking on checkbox or radio button now changes the value and propagated the click event.  If `preventDefault`, the
value is changed back.

    411 tests
    6.0 sec to complete


## Version 0.12.12 2012-01-16

Added element offset properties.  Google Maps demand these.

    406 tests
    5.9 sec to complete


## Version 0.12.11 2012-01-06

Maintenance update, mostly more test coverage, and updates to dependencies.

    403 tests
    4.4 sec to complete


## Version 0.12.10 2012-01-01

Brought back Web Sockets support (Justin Latimer)

Using JSDOM offsets (Justin Tulloss)

    388 tests
    3.8 sec to complete


## Version 0.12.9 2011-12-23

Added support for `httpOnly` cookies.

You can now call `browser.cookies` with no arguments to return cookies for the current domain (based on the hostname of
the currently loaded page).

You can now pass `referer` header:

    browser.visit("/page", referer: "http://google.com", function() {
      . . .
    })

Apply 5 second time limit on `browser.wait`, even if there's something going on (e.g. pull requests).

    387 tests
    3.9 sec to complete


## Version 0.12.8 2011-12-20

Browser implementations of clearInterval/clearTimeout do not throw exceptions (Justin Tulloss)

Fix resources.toString throwing an error (Mr Rogers)

    374 tests
    3.9 sec to complete


## Version 0.12.7 2011-12-19

Methods like `visit` and `fire` no longer call `wait` if there's no callback.

The wait callback is called from `nextTick`.  Fixes a possible race condition.

    366 Tests
    3.7 sec to complete


## Version 0.12.6 2011-12-18

You can now tell `browser.wait` when to complete processing events by passing either duration (in milliseconds) or a
function that returns true when done.  For example:

    browser.wait(500, function() {
      // Waits no longer than 0.5 second
    })

    function mapIsVisible(window) {
      return window.querySelector("#map");
    }
    browser.wait(mapIsVisible, function() {
      // Waits until the map element is visible on the page
    })

Reduced default `waitFor` from 5 seconds to 0.5 seconds.  That seems good enough default for most pages.

    366 Tests
    3.7 sec to complete


## Version 0.12.5 2011-12-16

`Zombie` and `Browser` are no longer distinct namespaces.  What you require is the `Browser` class that also includes
all the methods previously defined for `Zombie`.  For example:

    var Browser = require("zombie")

    // This setting applies to all browsers
    Browser.debug = true
    // Create and use a new browser instance
    var browser = new Browser()
    browser.visit("http://localhost:3001", function() {
      ...
    })

Added `browser.history` for accessing history for the current window, `browser.back` for navigating to the previous page
and `browser.reload` for reloading the current page.

Fixed a bug whereby navigating back in push-state history would reload document.

    363 Tests
    2.4 sec to complete


## Version 0.12.4 2011-12-16

Return undefined for response status when there is no response.

    362 Tests
    2.4 sec to complete


## Version 0.12.3 2011-12-13

Fixed issue when globally declared variables with no values are not accessible (Brian McDaniel)

    362 Tests
    2.6 sec to complete


## Version 0.12.2 2011-12-12

Added global options, for example:

    Zombie.site = "http://localhost:3003"
    Zombie.visit("/browser/test", function() {
      ...
    })

You can put Zombie in debug mode by setting environment variable `DEBUG`, for example:

    $ DEBUG=true vows

Also added `silent` option to suppress all `console.log` output from scripts.

Support origin in websockets (Glen Mailer)

Proper support for CSS style `opacity` property.

    360 Tests
    2.5 sec to complete


## Version 0.12.1 2011-12-06

Added `browser.success`, returns true if status code is 2xx.

Updated documentation to better reflect new API features and behaviors.  Catching up on the many changes since 0.11.

DOM events now dispatched asynchronously as part of event loop.

Allow `//<hostname>` URLs to be used in more places

    359 Tests
    2.4 sec to complete


## Version 0.12.0 2011-12-06

Zombie is now using real timers instead of the fake clock.  That means that a `setTimeout(fn, 5000)` will actually take
5 seconds to complete.

The `wait` method will wait for short timers (up to 5 seconds), which are quite common for some UI effects, setting up
the page, etc.  The maximum wait time is specified by the browser option `waitFor`.

If you need to wait longer, you can call `wait` with a time duration as the first argument.

Log redirect and error responses in debug mode.

    353 Tests
    2.4 sec to complete


## Version 0.11.8 2011-12-04

Added `browser.query` and `browser.queryAll`. Deprecated `browser.css`;
planning to use it for something else post 1.0.

Calling `html` or `text` when the document is not an HTML page returns
the text contents.  Particularly useful if you're looking at the
contents of what should be an HTML page, but got 404 or 500 insteas.

    357 Tests
    2.0 sec to complete


## Version 0.11.7 2011-11-30

Fixed `console.log` formatting `%s`, `%d` (Quang Van).

Fixed `viewInBrowser`.

Updated documentation to mention `browser.errors and
`browser.resources`, and that `cake watch` and `cake build` are no
longer necessary.

Fix to load cookies that contain equal signs and quotes in the value.

    347 Tests
    2.0 sec to complete


## Version 0.11.6 2011-11-27

Fixed loading of cookies/history from file, so empty lines are ignored.

Show JavaScript source location when failing to execute in script element.

Don't execute timer/interval that has been removed.

    347 Tests
    2.0 sec to complete


## Version 0.11.5 2011-11-27

Fixes `Browser is not defined` error.

    347 Tests
    2.0 sec to complete


## Version 0.11.4 2011-11-27

Added missing zombie.js.

    347 Tests
    2.0 sec to complete


## Version 0.11.3 2011-11-26

Iframes will now load their content when setting src attribute.

Internal changes: resources, event loop associated with browser, history
associated with window.

Updated installation instructions for Ubuntu.

    347 Tests
    2.2 sec to complete


## Version 0.11.2  2011-11-22

Send Content-Length in URL-encoded form requests (Sven Bange).

Added support for HTTP Basic and OAuth 2.0 authorization (Paul Dixon).

    344 Tests
    1.9 sec to complete


## Version 0.11.1  2011-11-21

Better error reporting when executing JS asynchronoulsy (timers, XHR).

Event loop keeps processing past errors.

    333 Tests
    1.8 sec to complete


## Version 0.11.0  2011-11-20

Changed error handling for the better.
    
Calling browser.wait or browser.visit no longer passed the
resource/JavaScript error as the first argument, and will continue
processing if there are multiple errors.
    
Instead, an array of errors is passed as the fourth argument.  You can
also access `browser.errors` and to get just the last one, e.g.  to
check if any errors were reported, use `browser.error`.


Using `console.log(browser)` will puke over your terminal, so we add
global defaults for sanity.

Set `console.depth` to specify how many times to recurse while
formatting the object (default is zero).

Set `console.showHidden` to show non-enumerable properties (defaults to
false).


    333 Tests
    1.7 sec to complete


## Version 0.10.3  2011-11-18

Added site option allowing you to call `visit` with a relative path.
Example:

    browser = new Browser(site: "localhost:3000")
    browser.visit("/testing", function(error, browser) {
    })

Fixed uploading of attachments to work with Connect/Express (and
possibly other servers).  Formidable (used by Connect) does not support
Base64 encoding.  Sending binary instead.

Tested on Node 0.6.1.

    330 Tests
    2.1 sec to complete


### Version 0.10.2  2011-10-13

Fixed #173 browser.open() causes Segmentation fault (Brian McDaniel)

Upgraded to JSDOM 0.2.7.


### Version 0.10.1  2011-09-08

Tests that this == window == top == parent.  True when evaluated within
the context of the browser, not necessarily when using browser.window.

Removed JSDOM patch for iframes, no tests failing, let's see what
happens ...

Fixes #164 jQuery selectors with explicit context fail.

Better stack traces for client-side JS.  This will help in debugging and
filing issues.
    
Updated installation instructions for OS X/Windows.

Upgraded to JSDOM 0.2.4 and testing with jQuery 1.6.3.

    329 Tests
    2.9 sec to complete


### Version 0.10.0  2011-08-27

Upgraded to [JSDOM](https://github.com/tmpvar/jsdom) 0.2.3 which brings
us a Window context that works for asynchronous invocations (that would
be timers, XHR and browser.evaluate), and many many other improvements.

Tested for compatibility with jQuery 1.6.2.  Yes.  It works.


*NOTE*: This release uses
[htmlparser](https://github.com/gmosx/htmlparser) as the default parser,
while waiting for some bug fixes on
[HTML5](https://github.com/aredridel/html5).  Unfortunately, htmlparser
is limited in what it can accept and properly parse.  Be aware of the
following issues:

- Your document *must* have `html`, `head` and `body` elements.
- No CDATAs. But then again, CDATA is so 1999.
- Tag soups break the parser.
- Scripts can't use `document.write`.  Again, it's not 1999.


Added `browser.loadCSS` option.  Set this to load external stylesheets.
Defaults to `true`.

Added `browser.htmlParser` option.  Tells JSDOM which HTML5 parser to
use.  Use `null` for the default parser.

Fixed handling of `file` protocol.


### Version 0.9.7  2011-07-28

Fixed: require.paths is deprecated [#158]

Fixed: missing pathname support for window.location.href [#156]

Fixed: not running script specs due to bug in CoffeeScript (iPaul
Covell) [#151]

Updated documentation to clarify installation instructions for OS X and
Ubuntu.

    311 Tests
    4.5 sec to complete


### Version 0.9.6  2011-07-28

Implements file:// requests using node.js' native fs module rather than
leaning on its http module (Ryan Petrello)

Added a basic infection/installation section to documentation (terryp)

Modified resources and xhr to better work with SSL (Ken Sternberg)


### Version 0.9.5  2011-04-11

Callbacks on input/select changes (Julien Guimont)

Fix type that broke compatibility with jQuery 1.5.1 (Chad Humphries)

Enabled window.Image to accept height and width attributes [#35]

Implemented window.navigator.javaEnabled() [#35]

Added setter for document.location [#90]

Fixed XPath Sorting / Specs (Blake Imsland)

    311 Tests
    4.5 sec to complete


### Version 0.9.4  2011-02-22

Added preliminary support for Web sockets (Ben Ford).

Fixes `eval` to execute in the global scope.

Fixes error when dumping cookies (Christian Joudrey).

Fixed some typos in the README (Jeff Hanke).

Speed bump from running on Node 0.4.1.

    295 Tests
    2.9 sec to complete


### Version 0.9.3  2011-02-22

Fixes seg fault when Zombie fails to compile a script.

    293 Tests
    3.3 sec to complete


### Version 0.9.2  2011-02-21

Fixes a couple of specs, plugs hole in array to prevent segfaults, and
adds try/catch to leave context after executing script.

    292 Tests
    3.3 sec to complete


### Version 0.9.1  2011-02-17

Some internal changes to history. Breaks iframe.

    289 Tests
    3.3 sec to complete


### Version 0.9.0  2011-02-17

New isolated contexts for executing JavaScript.  This solves a long
standing problems with pages that have more than one script.  Briefly
speaking, each window gets it's own context/global scope that is shared
by all scripts loaded for that page, but isolated from all other
windows.

Fixes error handling on timeout/XHR scripts, these now generate an
`onerror` event.

Eventloop is now associated with window instead of browser.

Fixes URL resolution in XHR requests with no port.

    293 Tests
    3.3 sec to complete


### Version 0.8.13  2011-02-11

Tested with Node 0.4.0.

Add support for IFRAMEs (Damian Janowski).

Upgraded to HTML5 0.2.13.

Fixes #71 cookie names now preserve case.

Fixes #69 incorrectly resolving partial URLs in XHR requests.

Fixes `browser.clock` to use `Date.now` instead of `new Date` (faster).

Fixes `browser.dump`.

In debug mode, show when firing timeout/interval.

Added `cake install`.

    293 Tests
    3.7 sec to complete


### Version 0.8.12  2011-02-01

Tested with Node 0.3.7 in preparation for Node 0.4.0.

Added `browser.fork` (Josh Adell):

> Return a new browser using a snapshot of this browser's state.  This
method clones the forked browser's cookies, history and storage.  The
two browsers are independent, actions you perform in one browser do not
affect the other.

> Particularly useful for constructing a state (e.g.  sign in, add items
to a shopping cart) and using that as the base for multiple tests, and
for running parallel tests in Vows.

Fix firing the `change` event on `SELECT` elements when using jQuery
(Damian Janowski).

Fix for `jQuery.ajax` receiving a non-string `data` option (Damian
Janowski).

Fix to allow `script` elements that are not JavaScript (Sean Coates).

NOTE: In this release I started running the test suite using `cake test`
and recording the time reported by Vows.  This doesn't count the
time it takes to fire up Node, Cake, etc, so the reported time is
approximately a second smaller than the previously reported time for
0.8.11.  All other things being equal.

    292 Tests
    3.7 sec to complete


### Version 0.8.11  2011-01-25

Added `browser.source` which returns the unmodified source of
the current page (Bob Lail).

Added support for the Referer header (Vinicius Baggio).

If cookies do not specify a path, they are set to the root path
rather than to the request path (Bob Lail).

Cookies are allowed to specify paths other than the request path
(Bob Lail).

Ensure fields are sent in the order they are described (José Valim).

Fix parsing of empty body (Vinicius Baggio).

Add support for window.screen (Damian Janowski).

Zombie now sends V0 cookies (Assaf Arkin).

Fix for loading scripts over SSL (Damian Janowski).

Added `window.resources` to return all resources loaded by the page
(including the page itself).  You can see what the page is up with:

    browser.window.resources.dump()

Modified `lastRequest`/`lastResponse` to use the window resources, fixed
`browser.status` and `browser.redirected` to only look at the page
resource itself.

    282 Tests
    4.3 sec to complete


### Version 0.8.10  2011-01-13

Allow setting cookies from subdomains (Damian Janowski & Michel Martens).

Modified `browser.fire` to fire MouseEvents as well (Bob Lail).

Added `window.title` accessor (Bob Lail).

Fixed `window.navigator.userAgent` to return `userAgent` property (same
as sent to server) (Assaf Arkin).

Added support for `alert`, `confirm` and `prompt` (Assaf Arkin).

Added accessors for status code from last respone (`browser.statusCode`)
and whether last response followed a redirect (`browser.redirected`)
(Assaf Arkin).

The `visit`, `clickLink` and `pressButton` methods now pass three
arguments to the callback: error, browser and status code (Assaf Arkin).

    265 Tests
    3.7 sec to complete



### Version 0.8.9  2011-01-10

Properly use the existance operator so empty strings are sent (José Valim).

Fix to XPath evaluation and sorting by document order (José Valim).

Added `unselect`, `selectOption` and `unselectOption` to browser (Bob
Lail).

Added `cookies.clear` (Bob Lail).

You can now call browser methods that accept a selector (e.g. `fill`,
`select`) with the element itself.

Fix to populate fields even if field type is invalid (Bob Lail).

Update to HTML5 0.2.12.

    238 Tests
    3.2 sec to complete


### Version 0.8.8  2011-01-04

Fixed script execution order: now in document order even when mixing
internal and external scripts.

Fixed image submit (José Valim).

Ensure checkboxes are properly serialized (José Valim).

It should send first select option if none was chosen (José Valim).

    231 Tests
    3.3 sec to complete


### Version 0.8.7  2011-01-04

Adds DOM Level 3 XPath support.

Added support for file upload: `browser.attach(selector, filename)`.

Send script errors to `window.onerror` and report them back to `visit`
callback.

Support `select` with multiple options (José Valim).

Fix handling of unknown input fields and select fields (José Valim).

Fix issue 24, search and hash must be empty string not null.

Support Node 0.3.3 (thanks [Pete Bevin](http://www.petebevin.com/))

For the brave enough to hack a Zombie, we now support (and `cake setup`
assumes) `npm bundle`.

    224 Tests
    3.1 sec to complete


### Version 0.8.6  2010-12-31

Now supports cookies on redirect (thanks [Łukasz
Piestrzeniewicz](https://github.com/bragi)).

Handle server returning multiple `Set-Cookie` headers.

The `clickLink` and `pressButton` methods should always pass to callback
and not throw error directly.

Now supports HTTPS.

    198 Tests
    2.6 sec to complete


### Version 0.8.5  2010-12-31

Re-implemented bcat in JavaScript, so no need to install bcat to use
Zombie.

    197 Tests
    2.6 sec to complete


### Version 0.8.4  2010-12-30

Added `browser.field` (find an input field, textarea, etc),
`browser.link` (find a link) and `browser.button` (find a button)
methods.

Added `browser.evaluate` to evaluate any arbitrary JavaScript in the
window context and return the result.

Added `browser.viewInBrowser` which uses `bcat` to view page in your
browser of choice.

    197 Tests
    2.6 sec to complete


### Version 0.8.3  2010-12-30

Zombie now shares global variables between scripts.

    199 Tests
    2.4 sec to complete


### Version 0.8.2  2010-12-30

Fixed bug whereby Zombie hangs when making requests to a URL that has no
path (e.g. `http://localhost`).

    198 Tests
    2.5 sec to complete


### Version 0.8.1  2010-12-29

Added User-Agent string.  You can change it by setting the browser
option `userAgent`.

There was an error with `browser.location`: documentation said it
returns a `Location` object but also just a URL.  Since `Location`
object is more consistent with `window.location`, accepted that
interpretation.

`Location.assign` did not load a page if the page was already loaded
in the browser.  Changed it to load the page (add caching later on).

    196 Tests
    2.6 sec to complete


### Version 0.8.0  2010-12-29

Fixed issue 8, wrong location of package.json.

Upgraded to JSDOM 0.1.22 and using HTML5 parser throughout.

Added browser.runScript option.  Set to false if you don't want the
browser to execute scripts.

You can now set browser options when initializing a new browser, on
existing `Browser` object or for the duration of a request by passing
them as second argument to `visit`.

Browser now has a property called `debug` that you can set to true/false
(was a function), and separately a method called `log` that logs
messages when debugging is enabled.

Added new page covering the browser API.

    194 Tests
    2.5 sec to complete


### Version 0.7.7  2010-12-28

Fix JSDOM queue and with it issue #6.

    189 Tests
    2.3 sec to complete


### Version 0.7.6  2010-12-28

HTML5 doesn't play nice with JSDOM, bringing back html-parser to handle
innerHTML (full document parsing still handled by HTML5).

Added documentation page for CSS selectors.

Man pages now moved to section 7.

Added zombie.version.

    189 Tests
    2.3 sec to complete


### Version 0.7.5  2010-12-28

Previous fix for document.write was incomplete, this one works better.

    189 Tests
    2.5 sec to complete


### Version 0.7.4  2010-12-28

Now parsing documents using HTML5, which can deal better with tag soup.

Added support for scripts that use document.write.

Added troublehsooting guide.

Fixed naming issue: browser.last_request is now lastRequest, same for
lastResponse and lastError.

    189 Tests
    2.5 sec to complete


### Version 0.7.3  2010-12-27

Fixed non-sensical error message when selector fails matching a node
(`fill`, `check`, `select`, etc).

Added debugging to help you figure out what's happening when tests run:
- Call `browser.debug` with a boolean to turn debugging on/off.
- Call `browser.debug` with a boolean and function to turn debugging
  on/off only while calling that function.
- Call `browser.debug` with multiple arguments to print them (same as
  `console.log`).
- Call `browser.debug` with a function to print the result of that
  function call.

Added an all revealing browser.dump: history, cookies, storage,
document, etc.  Simply call:
    browser.dump

Testing that Zombie.js can handle jQuery live form submit event.  Yes it
can!

    185 Tests
    1.8 sec to complete


### Version 0.7.2  2010-12-27

In CoffeeScript 1.0 loops no longer try preserve block scope when
functions are being generated within the loop body.  Unfortunately, this
broke a bunch of stuff when running Zombie from CoffeeScript source.  It
had effect when running the compiled JavaScript.

Changed: window.location now returns the same Location object until you
navigate to a different page.

    183 Tests
    1.8 sec to complete


### Version 0.7.1  2010-12-22

Removed CoffeeScript from runtime dependency list.


### Version 0.7.0  2010-12-22

Added `querySelector` and `querySelectorAll` based on the [DOM Selector
API](http://www.w3.org/TR/selectors-api/).  Use this instead of `find`
method.

Browser is now an EventEmitter, you can listen to drain (event queue
empty), error (loading page) and loaded (what is says).

You can now use `pressButton` with inputs of type button and reset
(previously just submit).

More, better, documentation.

    187 tests
    2.0 sec to complete


### Version 0.6.5  2010-12-21

Fixed lack of JavaScript source code: CoffeeScript moved to src,
JavaScript compiled into lib, life is grand again.

Changelog is now Markdown file and part of the documentation.


### Version 0.6.4  2010-12-21

First documentation you can actually use.


### Version 0.6.3  2010-12-21

Fixed documentation link.

`man zombie`


### Version 0.6.2  2010-12-21

First NPM release.

Started working on documentation site.

Added cake setup to get you up and running with development dependencies.

Remove Vows as runtime dependency.  Use whichever framework you like.  Moved
sizzle.js from dep to vendor.  Moved scripts used during tests to
spec/.scripts.

    178 tests
    1.8 sec to complete


### Version 0.6.1  2010-12-20

Changed browser.cookies from getter to function that accepts cookie domain
(host and port) and path, and returns wrapper to access specific cookie
context.

Fixed: browser now creates new window for each new document.

Added window.JSON.

    178 tests
    1.8 sec to complete


### Version 0.6.0  2010-12-20

First release that I could use to test an existing project.

Supports for navigation, filling and submitting forms, and selecting document
content using Sizzle. Browser features include evaluating JavaScript (jQuery,
Sammy.js), timers, XHR, cookies, local and session storage.

Still very rough around the edges.

    175 tests
    1.8 sec to complete
