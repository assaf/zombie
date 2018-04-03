# Zombie.js
### Insanely fast, headless full-stack testing using Node.js

[![NPM](https://img.shields.io/npm/v/zombie.svg?style=flat-square&label=latest)](https://www.npmjs.com/package/zombie)
[![Changelog](https://img.shields.io/badge/see-CHANGELOG-red.svg?style=flat-square)](https://github.com/assaf/zombie/blob/master/CHANGELOG.md)
[![Travis.ci](https://img.shields.io/travis/assaf/zombie.svg?style=flat-square)](https://travis-ci.org/assaf/zombie)
<img width="12" src="data:image/gif;base64,R0lGODlhAQABAPAAAP">
[![JS.ORG](https://img.shields.io/badge/js.org-zombie-ffb400.svg?style=flat-square)](http://js.org)

**Zombie 6.x** is tested to work with Node 8 or later.
If you need to use Node 6, consider using Zombie 5.x.



## The Bite

If you're going to write an insanely fast, headless browser, how can you not
call it Zombie?  Zombie it is.

Zombie.js is a lightweight framework for testing client-side JavaScript code in
a simulated environment.  No browser required.

Let's try to sign up to a page and see what happens:

```js
const Browser = require('zombie');

// We're going to make requests to http://example.com/signup
// Which will be routed to our test server localhost:3000
Browser.localhost('example.com', 3000);

describe('User visits signup page', function() {

  const browser = new Browser();

  before(function(done) {
    browser.visit('/signup', done);
  });

  describe('submits form', function() {

    before(function(done) {
      browser
        .fill('email',    'zombie@underworld.dead')
        .fill('password', 'eat-the-living')
        .pressButton('Sign Me Up!', done);
    });

    it('should be successful', function() {
      browser.assert.success();
    });

    it('should see welcome page', function() {
      browser.assert.text('title', 'Welcome To Brains Depot');
    });
  });
});
```

This example uses the [Mocha](https://github.com/mochajs/mocha) testing
framework, but Zombie will work with other testing frameworks.  Since Mocha
supports promises, we can also write the test like this:

```js
const Browser = require('zombie');

// We're going to make requests to http://example.com/signup
// Which will be routed to our test server localhost:3000
Browser.localhost('example.com', 3000);

describe('User visits signup page', function() {

  const browser = new Browser();

  before(function() {
    return browser.visit('/signup');
  });

  describe('submits form', function() {

    before(function() {
      browser
        .fill('email',    'zombie@underworld.dead')
        .fill('password', 'eat-the-living');
      return browser.pressButton('Sign Me Up!');
    });

    it('should be successful', function() {
      browser.assert.success();
    });

    it('should see welcome page', function() {
      browser.assert.text('title', 'Welcome To Brains Depot');
    });
  });

});
```

Well, that was easy.




## Table of Contents

* [Installing](#installing)
* [Browser](#browser)
* [Assertions](#assertions)
* [Cookies](#cookies)
* [Tabs](#tabs)
* [Debugging](#debugging)
* [Events](#events)
* [Resources](#resources)
* [Pipeline](#pipeline)




## Installing

To install Zombie.js you will need [Node.js](https://nodejs.org/):

```bash
$ npm install zombie --save-dev
```



## Browser

#### browser.assert

Methods for making assertions against the browser, such as
`browser.assert.element('.foo')`.

See [Assertions](#assertions) for detailed discussion.

#### browser.referer

You can use this to set the HTTP Referer header.

#### browser.resources

Access to history of retrieved resources.  See [Resources](#resources) for
detailed discussion.

#### browser.pipeline

Access to the pipeline for making requests and processing responses.  Use this
to add new request/response handlers the pipeline for a single browser instance,
or use `Pipeline.addHandler` to modify all instances.  See
[Pipeline](#pipeline).


#### browser.tabs

Array of all open tabs (windows).  Allows you to operate on more than one open
window at a time.

See [Tabs](#tabs) for detailed discussion.

#### browser.proxy

The `proxy` option takes a URL so you can tell Zombie what protocol, host and
port to use. Also supports Basic authentication, e.g.:

```js
browser.proxy = 'http://me:secret@myproxy:8080'
```

#### browser.errors

Collection of errors accumulated by the browser while loading page and executing
scripts.

#### browser.source

Returns a string of the source HTML from the last response.

#### browser.html(element)

Returns a string of HTML for a selected HTML element. If argument `element` is `undefined`, the function returns a string of the source HTML from the last response.

Example uses:

```
browser.html('div');
browser.html('div#contain');
browser.html('.selector');
browser.html();
```

#### Browser.localhost(host, port)

Allows you to make requests against a named domain and HTTP/S port, and will
route it to the test server running on localhost and unprivileged port.

For example, if you want to call your application "example.com", and redirect
traffic from port 80 to the test server that's listening on port 3000, you can
do this:

```js
Browser.localhost('example.com', 3000)
browser.visit('/path', function() {
  console.log(browser.location.href);
});
=> 'http://example.com/path'
```

The first time you call `Browser.localhost`, if you didn't specify
`Browser.site`, it will set it to the hostname (in the above example,
"example.com").  Whenever you call `browser.visit` with a relative URL, it
appends it to `Browser.site`, so you don't need to repeat the full URL in every
test case.

You can use wildcards to map domains and all hosts within these domains, and you
can specify the source port to map protocols other than HTTP.  For example:

```js
// HTTP requests for example.test www.example.test will be answered by localhost
// server running on port 3000
Browser.localhost('*.example.test', 3000);
// HTTPS requests will be answered by localhost server running on port 3001
Browser.localhost('*.example.test:443', 3001);
```

The underlying implementation hacks `net.Socket.connect`, so it will route any
TCP connection made by the Node application, whether Zombie or any other
library.  It does not affect other processes running on your machine.

### Browser.extend

You can use this to customize new browser instances for your specific needs.
The extension function is called for every new browser instance, and can change
properties, bind methods, register event listeners, etc.

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




## Assertions

To make life easier, Zombie introduces a set of convenience assertions that you
can access directly from the browser object.  For example, to check that a page
loaded successfully:

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
browser.assert.cookie('flash', 'Missing email address');
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
browser.assert.evaluate('$("form").data("valid")');
browser.assert.evaluate('$("form").data("errors").length', 3);
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
browser.assert.url({ pathname: '/foo/bar' });
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




## Cookies

Are delicious.  Also, somewhat tricky to work with.   A browser will only send a
cookie to the server if it matches the request domain and path.

Most modern Web applications don't care so much about the path and set all
cookies to the root path of the application (`/`), but do pay attention to the
domain.

Consider this code:

```js
browser.setCookie({ name: 'session', domain: 'example.com', value: 'delicious' });
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

#### browser.open (url)

Opens and returns a new tab.  Supported options are:
- `name` - Window name.
- `url` - Load document from this URL.

#### browser.window

Returns the currently active window, same as `browser.tabs.current.`




## Debugging

To see what your code is doing, you can use `console.log` and friends from both
client-side scripts and your test code.

To see everything Zombie does (opening windows, loading URLs, firing events,
etc), set the environment variable `DEBUG=zombie`.  Zombie uses the
[debug](https://github.com/visionmedia/debug) module.  For example:

```bash
$ DEBUG=zombie mocha
```

You can also turn debugging on from your code (e.g. a specific test you're
trying to troubleshoot) by calling `browser.debug()`.

Some objects, like the browser, history, resources, tabs and windows also
include `dump` method that will dump the current state to the console, or an
output stream of your choice.  For example:

```js
browser.dump();
browser.dump(process.stderr);
```

If you want to disable console output from scripts, set `browser.silent = true`
or once for all browser instances with `Browser.silent = true`.




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

#### error (error)

Error when loading a resource, or evaluating JavaScript.

#### evaluated (code, result, filename)

Emitted after JavaScript code is evaluated.

The first argument is the JavaScript function or code (string).  The second
argument is the result.  The third argument is the filename.

#### event (event, target)

Emitted whenever a DOM event is fired on the target element, document or window.

#### focus (element)

Emitted whenever an element receives the focus.

#### idle ()

Event loop is idle.

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

#### redirect (request, response)

Emitted when following a redirect.

#### request (request)

Emitted before making a request to retrieve a resource.

The first argument is the request object.  See [Resources](#resources) for more
details.

#### response (request, response)

Emitted after receiving the response (excluding redirects).

The first argument is the request object, the second argument is the response
object.  See [Resources](#resources) for more details.

#### serverEvent ()

Browser received server initiated event (e.g. `EventSource` message).

#### setInterval (function, interval)

Event loop fired a `setInterval` event.

#### setTimeout (function, delay)

Event loop fired a `setTimeout` event.

#### submit (url, target)

Emitted whenever a form is submitted.

The first argument is the URL of the new location, the second argument
identifies the target window (`_self`, `_blank`, window name, etc).

#### timeout (function, delay)

Emitted whenever a timeout (`setTimeout`) is fired.

The first argument is the function or code to evaluate, the second argument is
the delay in milliseconds.

#### xhr (event, url)

Called for each XHR event (`progress`, `abort`, `readystatechange`, `loadend`,
etc).




## Authentication

Zombie supports HTTP basic access authentication. To provide the login credentials:

```js
browser.on('authenticate', function(authentication) {
  authentication.username = 'myusername';
  authentication.password = 'mypassword';
});

browser.visit('/mypage');
```




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
  protocols or support new headers (see [Pipeline](#pipeline))


### The Resources List

Each browser provides access to the list of resources loaded by the currently
open window via `browser.resources`.  You can iterate over this list just like
any JavaScript array.

Each resource provides three properties:

- `request`   - The request object
- `response`  - The resource object (if received)
- `error`     - The error generated (no response)

The request object is based on the [Fetch API Request
object](https://fetch.spec.whatwg.org/#request-class).

The response object is based on the [Fetch API Response
object](https://fetch.spec.whatwg.org/#response-class).  Note that the fetch API
has the property `status`, whereas Node HTTP module uses `statusCode`.

#### browser.fetch(input, init)

You can use the browser directly to make requests against external resources.
These requests will share the same cookies, authentication and other browser
settings (also pipeline).

The `fetch` method is based on the [Fetch
API](https://fetch.spec.whatwg.org/#fetch-method).

For example:

```
browser.fetch(url)
  .then(function(response) {
    console.log('Status code:', response.status);
    if (response.status === 200)
      return response.text();
  })
  .then(function(text) {
    console.log('Document:', text);
  })
  .catch(function(error) {
    console.log('Network error');
  });
```

To access the response document body as a Node buffer, use the following:

```js
response.arrayBuffer()
  .then(Buffer) // arrayBuffer -> Buffer
  .then(function(buffer) {
    assert( Buffer.isBuffer(buffer) );
  });
```

#### resources.dump(output?)

Dumps the resources list to the output stream (defaults to standard output
stream).




## Pipeline

Zombie uses a pipeline to operate on resources.  You can extend that pipeline
with your own set of handlers, for example, to support additional protocols,
content types, special handlers, etc.

The pipeline consists of a set of handlers.  There are two types of handlers:

Functions with two arguments deal with requests.  They are called with the
browser and request object.  They may modify the request object, and they may
either return null (pass control to the next handler) or return the Response
object, or return a promise that resolves to either outcome.

Functions with three arguments deal with responses.  They are called with the
browser, request and response objects.  They may modify the response object, and
must return a Response object, either the same as the argument or a new Response
object, either directly or through a promise.

To add a new handle to the end of the pipeline:

```js
browser.pipeline.addHandler(function(browser, request) {
  // Let's delay this request by 1/10th second
  return new Promise(function(resolve) {
    setTimeout(resolve, 100);
  });
});
```

You can add handlers to all browsers via `Pipeline.addHandler`.  These
handlers are automatically added to every new `browser.pipeline` instance.

```js
Pipeline.addHandler(function(browser, request, response) {
  // Log the response body
  console.log('Response body: ' + response.body);
});
```

