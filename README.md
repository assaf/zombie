# Zombie.js
### Insanely fast, headless full-stack testing using Node.js

**NOTE:** This documentation is still work in progress.  Please help make it
better by adding as much as you can and submitting a pull request.

You can also consult [the older 1.4 documentation](http://zombie.labnotes.org).


## The Bite

If you're going to write an insanely fast, headless browser, how can you not
call it Zombie?  Zombie it is.

Zombie.js is a lightweight framework for testing client-side JavaScript code in
a simulated environment.  No browser required.

Let's try to sign up to a page and see what happens:

```js
const Browser = require('zombie');
const assert  = require('assert');

// We call our test example.com
Browser.localhost('example.com', 3000);

// Load the page from localhost
const browser = new Browser();
browser.visit('/signup', function (error) {
  assert.ifError(error);

  // Fill email, password and submit form
  browser.
    fill('email', 'zombie@underworld.dead').
    fill('password', 'eat-the-living').
    pressButton('Sign Me Up!', function(error) {
      assert.ifError(error);

      // Form submitted, new page loaded.
      browser.assert.success();
      browser.assert.text('title', 'Welcome To Brains Depot');

    });

});
```

If you prefer using promises:

```js
const Browser = require('zombie');

// We call our test example.com
Browser.localhost('example.com', 3000);

// Load the page from localhost
const browser = new Browser();
browser.visit('/signup')
  .then(function() {
    // Fill email, password and submit form
    browser.fill('email', 'zombie@underworld.dead');
    browser.fill('password', 'eat-the-living');
    return browser.pressButton('Sign Me Up!');
  })
  .then(function() {
    // Form submitted, new page loaded.
    browser.assert.success();
    browser.assert.text('title', 'Welcome To Brains Depot');
  });
```

Well, that was easy.




## Table of Contents

* [Installing](#installing)
* [Browser](#browser)
* [Cookies](#cookies)
* [Tabs](#tabs)
* [Assertions](#assertions)
* [Events](#events)
* [Resources](#resources)
* [Debugging](#debugging)
* [FAQ](#faq)




## Installing

To install Zombie.js you will need [Node.js](http://nodejs.org/) 0.8 or later,
[NPM](https://npmjs.org/), a [C++ toolchain and
Python](https://github.com/TooTallNate/node-gyp).

One-click installers for Windows, OS X, Linux and SunOS are available directly
from the [Node.js site](http://nodejs.org/download/).

On OS X you can download the full XCode from the Apple Store, or install the
[OSX GCC toolchain](https://github.com/kennethreitz/osx-gcc-installer) directly
(smaller download).

You can also install Node and NPM using the wonderful
[Homebrew](http://mxcl.github.com/homebrew/) (if you're serious about developing
on the Mac, you should be using Homebrew):

```sh
$ brew install node
$ node --version
v0.10.25
$ npm --version
1.3.24
$ npm install zombie --save-dev
```

On Windows you will need to install a recent version of Python and Visual
Studio. See [node-gyp for specific installation
instructions](https://github.com/TooTallNate/node-gyp) and
[Chocolatey](http://chocolatey.org/) for easy package management.




## Browser

#### browser.assert

Methods for making assertions against the browser, such as
`browser.assert.element('.foo')`.

See [Assertions](#assertions) for detailed discussion.

#### browser.console

Provides access to the browser console (same as `window.console`).

#### browser.referer

You can use this to set the HTTP Referer header.

#### browser.resources

Access to history of retrieved resources.  Also provides methods for retrieving
resources and managing the resource pipeline.  When things are not going your
way, try calling `browser.resources.dump()`.

See [Resources](#resources) for detailed discussion.

#### browser.tabs

Array of all open tabs (windows).  Allows you to operate on more than one open
window at a time.

See [Tabs](#tabs) for detailed discussion.

#### Browser.localhost(host, port)

Allows you to make requests against a named domain and HTTP/S port, and will
route it to the test server running on localhost and unprivileged port.

For example, if you want to call your application "example.com", and redirect
traffic from port 80 to the test server that's listening on port 3000, you can
do this:

```javascript
Browser.localhost('example.com', 3000)
browser.visit('/path', function() {
  assert(broswer.location.href == 'http://example.com/path');
});
```

The first time you call `Browser.localhost`, if you didn't specify
`Browser.site`, it will set it to the hostname (in the above example,
"example.com").  Whenever you call `browser.visit` with a relative URL, it
appends it to `Browser.site`, so you don't need to repeat the full URL in every
test case.

You can use wildcards to map domains and all hosts within these domains, and you
can specify the source port to map protocols other than HTTP.  For example:

```javascript
// HTTP requests for example.test www.example.test will be answered by localhost
// server running on port 3000
Browser.localhost('*.example.test', 3000);
// HTTPS requests will be answered by localhost server running on port 3001
Browser.localhost('*.example.test:443', 3001);
```

The underlying implementation hacks `net.Socket.connect`, so it will route any
TCP connection made by the Node application, whether Zombie or any other
library.  It does not affect other processes running on your machine.


#### browser.proxy

The `proxy` option takes a URL so you can tell Zombie what protocol, host and port to use. Also supports Basic authentication, e.g.:

    browser.proxy = "http://me:secret@myproxy:8080"


#### browser.eventLoop
#### browser.errors


### Extending The Browser

```js
Browser.extend(function(browser) {
  browser.on('console', function(level, message) {
    logger.log(message);
  });
  browser.on('log', function(level, message) {
    logger.log(message);
  });
});
```


## Cookies

Are delicious.  Also, somewhat tricky to work with.   A browser will only send a
cookie to the server if it matches the request domain and path.

Most modern Web applications don't care so much about the path and set all
cookies to the root path of the application (`/`), but do pay attention to the
domain.

Consider this code:

```js
browser.setCookie(name: 'session', domain: 'example.com', value: 'delicious');
browser.visit('http://example.com', function() {
  const value = browser.getCookie('session');
  console.log('Cookie', value);
});
```

In order for the cookie to be set in this example, we need to specify the cookie
name, domain and path.  In this example we omit the path and choose the default
`/`.

To get the cookie in this example, we only need the cookie name, because at that
point the browser has an open document, and it can use the domain of that
document to find the right cookie.  We do need to specify a domain if we're
interested in other cookies, e.g for a 3rd party widget.

There may be multiple cookies that match the same host, for example, cookies set
for `.example.com` and `www.example.com` will both match `www.example.com`, but
only the former will match `example.com`.  Likewise, cookies set for `/` and
`/foo` will both match a request for `/foo/bar`.

`getCookie`, `setCookie` and `deleteCookie` always operate on a single cookie,
and they match the most specific one, starting with the cookies that have the
longest matching domain, followed by the cookie that has the longest matching
path.

If the first argument is a string, they look for a cookie with that name using
the hostname of the currently open page as the domain and `/` as the path.  To
be more specific, the first argument can be an object with the properties
`name`, `domain` and `path`.

The following are equivalent:

```js
browser.getCookie('session');
browser.getCookie({ name: 'session',
                    domain: browser.location.hostname,
                    path: browser.location.pathname });
```


`getCookie` take a second argument.  If false (or missing), it returns the
value of the cookie.  If true, it returns an object with all the cookie
properties: `name`, `value`, `domain`, `path`, `expires`, `httpOnly` and
`secure`.


#### browser.cookies

Returns an object holding all cookies used by this browser.

#### browser.cookies.dump(output?)

Dumps all cookies to standard output, or the output stream.

#### browser.deleteCookie(identifier)

Deletes a cookie matching the identifier.

The identifier is either the name of a cookie, or an object with the property
`name` and the optional properties `domain` and `path`.

#### browser.deleteCookies()

Deletes all cookies.

#### browser.getCookie(identifier, allProperties?)

Returns a cookie matching the identifier.

The identifier is either the name of a cookie, or an object with the property
`name` and the optional properties `domain` and `path`.

If `allProperties` is true, returns an object with all the cookie properties,
otherwise returns the cookie value.

#### browser.setCookie(name, value)

Sets the value of a cookie based on its name.

#### browser.setCookie(cookie)

Sets the value of a cookie based on the following properties:

* `domain` - Domain of the cookie (requires, defaults to hostname of currently
  open page)
* `expires` - When cookie it set to expire (`Date`, optional, defaults to
  session)
* `maxAge` - How long before cookie expires (in seconds, defaults to session)
* `name` - Cookie name (required)
* `path` - Path for the cookie (defaults to `/`)
* `httpOnly` - True if HTTP-only (not accessible from client-side JavaScript,
  defaults to false)
* `secure` - True if secure (requires HTTPS, defaults to false)
* `value` - Cookie value (required)




## Tabs

Just like your favorite Web browser, Zombie manages multiple open windows as
tabs.  New browsers start without any open tabs.  As you visit the first page,
Zombie will open a tab for it.

All operations against the `browser` object operate on the currently active tab
(window) and most of the time you only need to interact with that one tab.  You
can access it directly via `browser.window`.

Web pages can open additional tabs using the `window.open` method, or whenever a
link or form specifies a target (e.g. `target=_blank` or `target=window-name`).
You can also open additional tabs by calling `browser.open`.  To close the
currently active tab, close the window itself.

You can access all open tabs from `browser.tabs`.  This property is an
associative array, you can access each tab by its index number, and iterate over
all open tabs using functions like `forEach` and `map`.

If a window was opened with a name, you can also access it by its name.  Since
names may conflict with reserved properties/methods, you may need to use
`browser.tabs.find`.

The value of a tab is the currently active window.  That window changes when you
navigate forwards and backwards in history.  For example, if you visited the URL
'/foo' and then the URL '/bar', the first tab (`browser.tabs[0]`) would be a
window with the document from '/bar'.  If you then navigate back in history, the
first tab would be the window with the document '/foo'.

The following operations are used for managing tabs:

#### browser.close(window)

Closes the tab with the given window.

#### browser.close()

Closes the currently open tab.

#### browser.tabs

Returns an array of all open tabs.

#### browser.tabs[number]

Returns the tab with that index number.

#### browser.tabs[string]
#### browser.tabs.find(string)

Returns the tab with that name.

#### browser.tabs.closeAll()

Closes all tabs.

#### browser.tabs.current

This is a read/write property.  It returns the currently active tab.

Can also be used to change the currently active tab.  You can set it to a
window (e.g. as currently returned from `browser.current`), a window name or the
tab index number.

#### browser.tabs.dump(output?)

Dump a list of all open tabs to standard output, or the output stream.

#### browser.tabs.index

Returns the index of the currently active tab.

#### browser.tabs.length

Returns the number of currently opened tabs.

#### browser.open(url: 'http://example.com')

Opens and returns a new tab.  Supported options are:
- `name` - Window name.
- `url` - Load document from this URL.

#### browser.window

Returns the currently active window, same as `browser.tabs.current.`




## Assertions

To make life easier, Zombie introduces a set of convenience assertions that you
can access directly from the browser object.  For example, to check that a page
loaded successfuly:

```js
browser.assert.success();
browser.assert.text('title', 'My Awesome Site');
browser.assert.element('#main');
```

These assertions are available from the `browser` object since they operate on a
particular browser instance -- generally dependent on the currently open window,
or document loaded in that window.

Many assertions require an element/elements as the first argument, for example,
to compare the text content (`assert.text`), or attribute value
(`assert.attribute`).  You can pass one of the following values:

- An HTML element or an array of HTML elements
- A CSS selector string (e.g. "h2", ".book", "#first-name")

Many assertions take an expected value and compare it against the actual value.
For example, `assert.text` compares the expected value against the text contents
of one or more strings.  The expected value can be one of:

- A JavaScript primitive value (string, number)
- `undefined` or `null` are used to assert the lack of value
- A regular expression
- A function that is called with the actual value and returns true if the
  assertion is true
- Any other object will be matched using `assert.deepEqual`

Note that in some cases the DOM specification indicates that lack of value is an
empty string, not `null`/`undefined`.

All assertions take an optional last argument that is the message to show if the
assertion fails.  Better yet, use a testing framework like
[Mocha](https://github.com/mochajs/mocha) that has good diff support and
don't worry about these messages.


### Available Assertions

The following assertions are available:

#### assert.attribute(selection, name, expected, message)

Asserts the named attribute of the selected element(s) has the expected value.

Fails if no element found.

```js
browser.assert.attribute('form', 'method', 'post');
browser.assert.attribute('form', 'action', '/customer/new');
// Disabled with no attribute value, i.e. <button disabled>
browser.assert.attribute('button', 'disabled', '');
// No disabled attribute i.e. <button>
browser.assert.attribute('button', 'disabled', null);
```

#### assert.className(selection, className, message)

Asserts that selected element(s) has that and only that class name.  May also be
space-separated list of class names.

Fails if no element found.

```js
browser.assert.className('form input[name=email]', 'has-error');
```

#### assert.cookie(identifier, expected, message)

Asserts that a cookie exists and  has the expected value, or if `expected` is
`null`, that no such cookie exists.

The identifier is either the name of a cookie, or an object with the property
`name` and the optional properties `domain` and `path`.

```js
browser.assert.cookie('flash', 'Missing email addres');
```

#### assert.element(selection, message)

Asserts that one element matching selection exists.

Fails if no element or more than one matching element are found.

```js
browser.assert.element('form');
browser.assert.element('form input[name=email]');
browser.assert.element('form input[name=email].has-error');
```

#### assert.elements(selection, count, message)

Asserts how many elements exist in the selection.

The argument `count` can be a number, or an object with the following
properties:

- `atLeast` - Expecting to find at least that many elements
- `atMost`  - Expecting to find at most that many elements
- `exactly` - Expecting to find exactly that many elements

```js
browser.assert.elements('form', 1);
browser.assert.elements('form input', 3);
browser.assert.elements('form input.has-error', { atLeast: 1 });
browser.assert.elements('form input:not(.has-error)', { atMost: 2 });
```

#### assert.evaluate(expression, expected, message)

Evaluates the JavaScript expression in the context of the currently open window.

With one argument, asserts that the value is equal to `true`.

With two/three arguments, asserts that the returned value matches the expected
value.

```js
browser.assert.evaluate('$('form').data('valid')');
browser.assert.evaluate('$('form').data('errors').length', 3);
```

#### assert.global(name, expected, message)

Asserts that the global (window) property has the expected value.

#### assert.hasClass(selection, className, message)

Asserts that selected element(s) have the expected class name.  Elements may
have other class names (unlike `assert.className`).

Fails if no element found.

```js
browser.assert.hasClass('form input[name=email]', 'has-error');
```

#### assert.hasFocus(selection, message)

Asserts that selected element has the focus.

If the first argument is `null`, asserts that no element has the focus.

Otherwise, fails if element not found, or if more than one element found.

```js
browser.assert.hasFocus('form input:nth-child(1)');
```

#### assert.hasNoClass(selection, className, message)

Asserts that selected element(s) does not have the expected class name.  Elements may
have other class names (unlike `assert.className`).

Fails if no element found.

```js
browser.assert.hasNoClass('form input', 'has-error');
```

#### assert.input(selection, expected, message)

Asserts that selected input field(s) (`input`, `textarea`, `select` etc) have
the expected value.

Fails if no element found.

```js
browser.assert.input('form input[name=text]', 'Head Eater');
```

#### assert.link(selection, text, url, message)

Asserts that at least one link exists with the given selector, text and URL.
The selector can be `a`, but a more specific selector is recommended.

URL can be relative to the current document, or a regular expression.

Fails if no element is selected that also has the specified text content and
URL.

```js
browser.assert.link('footer a', 'Privacy Policy', '/privacy');
```

#### assert.redirected(message)

Asserts the browser was redirected when retrieving the current page.

#### assert.success(message)

Asserts the current page loaded successfully (status code 2xx or 3xx).

#### assert.status(code, message)

Asserts the current page loaded with the expected status code.

```js
browser.assert.status(404);
```

#### assert.style(selection, style, expected, message)

Asserts that selected element(s) have the expected value for the named style
property.  For example:

Fails if no element found, or element style does not match expected value.

```js
browser.assert.style('#show-hide.hidden', 'display', 'none');
browser.assert.style('#show-hide:not(.hidden)', 'display', '');
```

#### assert.text(selection, expected, message)

Asserts that selected element(s) have the expected text content.  For example:

Fails if no element found that has that text content.

```js
browser.assert.text('title', 'My Awesome Page');
```

#### assert.url(url, message)

Asserts the current page has the expected URL.

The expected URL can be one of:

- The full URL as a string
- A regular expression
- A function, called with the URL and returns true if the assertion is true
- An [object](http://nodejs.org/api/url.html#url_url_parse_urlstr_parsequerystring_slashesdenotehost), in which case individual properties are matched against the URL

For example:

```js
browser.assert.url('http://localhost/foo/bar');
browser.assert.url(new RegExp('^http://localhost/foo/\\w+$'));
browser.assert.url({ pathame: '/foo/bar' });
browser.assert.url({ query: { name: 'joedoe' } });
```


### Roll Your Own Assertions

Not seeing an assertion you want?  You can add your own assertions to the
prototype of `Browser.Assert`.

For example:

```js
// Asserts the browser has the expected number of open tabs.
Browser.Assert.prototype.openTabs = function(expected, message) {
  assert.equal(this.browser.tabs.length, expected, message);
};
```

Or application specific:


```js
// Asserts which links is highlighted in the navigation bar
Browser.Assert.navigationOn = function(linkText) {
  this.assert.element('.navigation-bar');
  this.assert.text('.navigation-bar a.highlighted', linkText);
};
```




## Events

Each browser instance is an `EventEmitter`, and will emit a variety of events
you can listen to.

Some things you can do with events:

- Trace what the browser is doing, e.g. log every page loaded, every DOM event
  emitted, every timeout fired
- Wait for something to happen, e.g. form submitted, link clicked, input element
  getting the focus
- Strip out code from HTML pages, e.g remove analytics code when running tests
- Add event listeners to the page before any JavaScript executes
- Mess with the browser, e.g. modify loaded resources, capture and change DOM
  events

#### console (level, message)

Emitted whenever a message is printed to the console (`console.log`,
`console.error`, `console.trace`, etc).

The first argument is the logging level, and the second argument is the message.

The logging levels are: `debug`, `error`, `info`, `log`, `trace` and `warn`.

#### active (window)

Emitted when this window becomes the active window.

#### closed (window)

Emitted when this window is closed.

#### done ()

Emitted when the event loop goes empty.

#### evaluated (code, result, filename)

Emitted after JavaScript code is evaluated.

The first argument is the JavaScript function or code (string).  The second
argument is the result.  The third argument is the filename.

#### event (event, target)

Emitted whenever a DOM event is fired on the target element, document or window.

#### focus (element)

Emitted whenever an element receives the focus.

#### inactive (window)

Emitted when this window is no longer the active window.

#### interval (function, interval)

Emitted whenever an interval (`setInterval`) is fired.

The first argument is the function or code to evaluate, the second argument is
the interval in milliseconds.

#### link (url, target)

Emitted when a link is clicked.

The first argument is the URL of the new location, the second argument
identifies the target window (`_self`, `_blank`, window name, etc).

#### loaded (document)

Emitted when a document has been loaded into a window or frame.

This event is emitted after the HTML is parsed, and some scripts executed.

#### loading (document)

Emitted when a document is about to be loaded into a window or frame.

This event is emitted when the document is still empty, before parsing any HTML.

#### opened (window)

Emitted when a new window is opened.

#### redirect (request, response, redirectRequest)

Emitted when following a redirect.

The first argument is the request, the second argument is the response that
caused the redirect, and the third argument is the new request to follow the
redirect.  See [Resources](#resources) for more details.

The URL of the new resource to retrieve is given by `response.url`.

#### request (request)

Emitted before making a request to retrieve a resource.

The first argument is the request object.  See [Resources](#resources) for more
details.

#### response (request, response)

Emitted after receiving the response (excluding redirects).

The first argument is the request object, the second argument is the response
object.  See [Resources](#resources) for more details.

#### submit (url, target)

Emitted whenever a form is submitted.

The first argument is the URL of the new location, the second argument
identifies the target window (`_self`, `_blank`, window name, etc).

#### timeout (function, delay)

Emitted whenever a timeout (`setTimeout`) is fired.

The first argument is the function or code to evaluate, the second argument is
the delay in milliseconds.




## Resources

Zombie can retrieve with resources - HTML pages, scripts, XHR requests - over
HTTP, HTTPS and from the file system.

Most work involving resources is done behind the scenes, but there are few
notable features that you'll want to know about. Specifically, if you need to do
any of the following:

- Inspect the history of retrieved resources, useful for troubleshooting issues
  related to resource loading
- Request resources directly, but have Zombie handle cookies, authentication,
  etc
- Implement new mechanism for retrieving resources, for example, add new
  protocols or support new headers


### The Resources List

Each browser provides access to its resources list through `browser.resources`.

The resources list is an array of all resources requested by the browser.  You
can iterate and manipulate it just like any other JavaScript array.

Each resource provides four properties:

- `request`   - The request object
- `response`  - The resource object (if received)
- `error`     - The error received instead of response
- `target`    - The target element or document (when loading HTML page, script,
  etc)

The request object consists of:

- `method`      - HTTP method, e.g. "GET"
- `url`         - The requested URL
- `headers`     - All request headers
- `body`        - The request body can be `Buffer` or string; only applies to
  POST and PUT methods
- `multipart`  - Used instead of a body to support file upload
- `time`        - Timestamp when request was made
- `timeout`     - Request timeout (0 for no timeout)

The response object consists of:

- `url`         - The actual URL of the resource; different from request URL if
  there were any redirects
- `statusCode`  - HTTP status code, eg 200
- `statusText`  - HTTP static code as text, eg "OK"
- `headers`     - All response headers
- `body`        - The response body, may be `Buffer` or string, depending on the
  content type encoding
- `redirects`   - Number of redirects followed (0 if no redirects)
- `time`        - Timestamp when response was completed

Request for loading pages and scripts include the target DOM element or
document. This is used internally, and may also give you more insight as to why
a request is being made.


### The Pipeline

Zombie uses a pipeline to operate on resources.  You can extend that pipeline
with your own set of handlers, for example, to support additional protocols,
content types, special handlers, etc.

The pipeline consists of a set of handlers.  There are two types of handlers:

Functions with two arguments deal with requests.  They are called with the
request object and a callback, and must call that callback with one of:

- No arguments to pass control to the next handler
- An error to stop processing and return that error
- `null` and the response objec to return that response

Functions with three arguments deal with responses.  They are called with the
request object, response object and a callback, and must call that callback with
one of:

- No arguments to pass control to the next handler
- An error to stop processing and return that error

To add a new handle to the end of the pipeline:

```js
browser.resources.addHandler(function(request, next) {
  // Let's delay this request by 1/10th second
  setTimeout(function() {
    Resources.httpRequest(request, next);
  }, Math.random() * 100);
});
```

If you need anything more complicated, you can access the pipeline directly via
`browser.resources.pipeline`.

You can add handlers to all browsers via `Browser.Resources.addHandler`.  These
handlers are automatically added to every new `browser.resources` instance.

```js
Browser.Resources.addHandler(function(request, response, next) {
  // Log the response body
  console.log('Response body: ' + response.body);
  next();
});
```

When handlers are executed, `this` is set to the browser instance.


### Operating On Resources

If you need to retrieve or operate on resources directly, you can do that as
well, using all the same features available to Zombie, including cookies,
authentication, etc.

#### resources.addHandler(handler)

Adds a handler to the pipeline of this browser instance.  To add a handler to the
pipeline of every browser instance, use `Browser.Resources.addHandler`.

#### resources.dump(output?)

Dumps the resources list to the output stream (defaults to standard output
stream). 

#### resources.pipeline

Returns the current pipeline (array of handlers) for this browser instance.

#### resources.get(url, callback)

Retrieves a resource with the given URL and passes response to the callback.

For example:

```js
browser.resources.get('http://some.service', function(error, response) {
  console.log(response.statusText);
  console.log(response.body);
});
```

#### resources.post(url, options, callback)

Posts a document to the resource with the given URL and passes the response to
the callback.

Supported options are:

- `body`- Request document body
- `headers` - Headers to include in the request
- `params` - Parameters to pass in the document body
- `timeout` - Request timeout in milliseconds (0 or `null` for no timeout)

For example:

```js
const params  = {
  'count': 5
};
browser.resources.post(
  'http://some.service',
   { params: params },
   function(error, response) {
  . . .
});

const headers = {
  'Content-Type': 'application/x-www-form-urlencoded'
};
browser.resources.post(
  'http://some.service',
   { headers: headers, body: 'count=5' },
   function(error, response) {
   . . .
});
```


#### resources.request(method, url, options, callback)

Makes an HTTP request to the resource and passes the response to the callback.

Supported options are:

- `body`- Request document body
- `headers` - Headers to include in the request
- `params` - Parameters to pass in the query string (`GET`, `DELETE`) or
  document body (`POST`, `PUT`)
- `timeout` - Request timeout in milliseconds (0 or `null` for no timeout)

For example:

```js
browser.resources.request('DELETE',
                          'http://some.service',
                          function(error) {
  . . .
});
```



## Debugging

To see what your code is doing, you can use `console.log` and friends from both
client-side scripts and your test code.

If you want to disable console output from scripts, set `browser.silent = true`
or once for all browser instances with `Browser.silent = true`.

For more details about what Zombie is doing (windows opened, requests made,
event loop, etc), run with the environment variable `DEBUG=zombie`. Alternatively,
you can enable debugging on the browser constructor function itself; i.e. `browser.debug()`

Zombie uses the [debug](https://github.com/visionmedia/debug) module, so if your
code also uses it, you can selectively control which modules should output debug
information.

Some objects, like the browser, history, resources, tabs and windows also
include `dump` method that will dump the current state to the console.




## FAQ

**Q:** Why won't Zombie work with [insert some web site]?

**A:** Zombie was designed for testing, not for web scraping.  You can use it
for whatever purpose you want, just to be clear:

1. Zombie cannot scrape many popular web sites, that's known
2. The core contributors are not concerned by that, not even a little


**Q:** How do I find position/location/styling of element?

**A:** Unlike a Web browser, Zombie doesn't visually render the HTML document.
It gives you access to the DOM, but since it doesn't attempt to render and
layout elements, it doesn't have information like position, location, etc.


**Q:** Does Zombie handle XHR sync/document.write/CDATA?

**A:** Those are some of the things we thought were good ideas in 1999.  It's
time to let go and move on.

