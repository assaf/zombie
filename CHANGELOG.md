zombie.js-changelog(7) -- Changelog
===================================


## Version 0.8.2  2010-12-30

Fixed bug where Zombie hangs when making requests to URL that have no
path (e.g. `http://localhost`).

    198 Tests
    2.5 sec to complete


## Version 0.8.1  2010-12-29

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


## Version 0.8.0  2010-12-29

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


## Version 0.7.7  2010-12-28

Fix JSDOM queue and with it issue #6. 

    189 Tests
    2.3 sec to complete


## Version 0.7.6  2010-12-28

HTML5 doesn't play nice with JSDOM, bringing back html-parser to handle
innerHTML (full document parsing still handled by HTML5).

Added documentation page for CSS selectors.
    
Man pages now moved to section 7.
    
Added zombie.version.

    189 Tests
    2.3 sec to complete


## Version 0.7.5  2010-12-28

Previous fix for document.write was incomplete, this one works better.

    189 Tests
    2.5 sec to complete


## Version 0.7.4  2010-12-28

Now parsing documents using HTML5, which can deal better with tag soup.

Added support for scripts that use document.write.

Added troublehsooting guide.

Fixed naming issue: browser.last_request is now lastRequest, same for
lastResponse and lastError.

    189 Tests
    2.5 sec to complete


## Version 0.7.3  2010-12-27

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


## Version 0.7.2  2010-12-27

In CoffeeScript 1.0 loops no longer try preserve block scope when
functions are being generated within the loop body.  Unfortunately, this
broke a bunch of stuff when running Zombie from CoffeeScript source.  It
had effect when running the compiled JavaScript.

Changed: window.location now returns the same Location object until you
navigate to a different page.

    183 Tests
    1.8 sec to complete


## Version 0.7.1  2010-12-22

Removed CoffeeScript from runtime dependency list.


## Version 0.7.0  2010-12-22

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


## Version 0.6.5  2010-12-21

Fixed lack of JavaScript source code: CoffeeScript moved to src,
JavaScript compiled into lib, life is grand again.

Changelog is now Markdown file and part of the documentation.


## Version 0.6.4  2010-12-21

First documentation you can actually use.


## Version 0.6.3  2010-12-21

Fixed documentation link.

`man zombie`


## Version 0.6.2  2010-12-21

First NPM release.

Started working on documentation site.

Added cake setup to get you up and running with development dependencies.

Remove Vows as runtime dependency.  Use whichever framework you like.  Moved
sizzle.js from dep to vendor.  Moved scripts used during tests to
spec/.scripts.

    178 tests
    1.8 sec to complete


## Version 0.6.1  2010-12-20

Changed browser.cookies from getter to function that accepts cookie domain
(host and port) and path, and returns wrapper to access specific cookie
context.

Fixed: browser now creates new window for each new document.

Added window.JSON.

    178 tests
    1.8 sec to complete


## Version 0.6.0  2010-12-20

First release that I could use to test an existing project.

Supports for navigation, filling and submitting forms, and selecting document
content using Sizzle. Browser features include evaluating JavaScript (jQuery,
Sammy.js), timers, XHR, cookies, local and session storage.

Still very rough around the edges.

    175 tests
    1.8 sec to complete
