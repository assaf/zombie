# CHANGELOG #

### Version 0.7.0  2010-12-22

Added `querySelector` and `querySelectorAll` based on the [DOM Selector
API](http://www.w3.org/TR/selectors-api/).  Use this instead of `find`
method.

Browser is now an EventEmitter, you can listen to drain (event queue
empty), error (loading page) and loaded (what is says).

You can now use `pressButton` with inputs of type button and reset
(previously just submit).

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
