zombie.js-changelog(7) -- Changelog
===================================


### Version 0.9.5  Pending

Fix type that broke compatibility with jQuery 1.5.1 (Chad Humphries)

Enabled window.Image to accept height and width attributes [#35]

Implemented window.navigator.javaEnabled() [#35]

Added setter for document.location [#90]

    302 Tests
    4.2 sec to complete


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
