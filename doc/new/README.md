# Zombie.js

## Browser

### `browser.assert`

Methods for making assertions against the browser, such as
`browser.assert.element(".foo")`.

See [Assertions](#assertions) for detailed discussion.

### `browser.console`

Provides access to the browser console (same as `window.console`).

### `browser.referer`

You can use this to set the HTTP Referer header.

### `browser.resources`

Access to history of retrieved resources.  Also provides methods for retrieving
resources and managing the resource pipeline.  When things are not going your
way, try calling `browser.resources.dump()`.

See [Resources](#resources) for detailed discussion.

### `browser.tabs`

Array of all open tabs (windows).  Allows you to operate on more than one open
window at a time.

See [Tabs](#tabs) for detailed discussion.

### `browser.eventLoop`
### `browser.errors`

### Extending The Browser

```
Browser.extend(function(browser) {
  browser.on("console", function(level, message) {
    logger.log(message);
  });
  browser.on("log", function(level, message) {
    logger.log(message);
  });
});
```



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
"/foo" and then the URL "/bar", the first tab (`browser.tabs[0]`) would be a
window with the document from "/bar".  If you then navigate back in history, the
first tab would be the window with the document "/foo".

The following operations are used for managing tabs:

### `browser.close(window)`

Closes the tab with the given window.

### `browser.close()`

Closes the currently open tab.

### `browser.tabs`

Returns an array of all open tabs.

### `browser.tabs[number]`

Returns the tab with that index number.

### `browser.tabs[string]`
### `browser.tabs.find(string)`

Returns the tab with that name.

### `browser.tabs.closeAll()`

Closes all tabs.

### `browser.tabs.current`

Returns the currently active tab.

### `browser.tabs.current = window`

Changes the currently active tab.  You can set it to a window (e.g. as currently
returned from `browser.current`), a window name or the tab index number.

### `browser.tabs.dump(output)`

Dump a list of all open tabs to standard output, or the output stream.

### `browser.tabs.index`

Returns the index of the currently active tab.

### `browser.tabs.length`

Returns the number of currently opened tabs.

### `browser.open(url: "http://example.com")`

Opens and returns a new tab.  Supported options are:
- `name` - Window name.
- `url` - Load document from this URL.

### `browser.window`

Returns the currently active window, same as `browser.tabs.current.`




## Assertions

Node.js core includes an `assert` function, and there are many alternatives you
can use for assertions and expectations.  Obviously Zombie will support all of
them.

To make your life easier, it also introduces a set of convenience assertions you
can execute directly against the browser object.  For example, to check that a
page load completed successfully, you may do:


```
browser.assert.success();
browser.assert.text("title", "My Awesome Site");
browser.assert.element("#main");
```

Assertions that take an expected value, will compare that against the actual
value.  The expected value can be a primitive JavaScript value (string, number,
etc), a regular expression or a function.  In the later case, the function is
called with the actual value, and the assertion passes if the function returns
true.

Assertions that take a CSS selector use it to retrieve an HTML element or
elements.  You can also pass the element(s) directly instead of a selector (e.g.
if you need to access an element inside an iframe).

All assertions take an optional last argument that is the message to show if the
assertion fails, but when using frameworks that has good reporting (e.g. Mocha)
you want to let the assertion format the message for you.

The following assertions are available:

### `browser.assert.attribute(selector, name, expected, message)`

Assert the named attribute of the selected element(s) has the expected value.
Fails if no elements found.

### `browser.assert.className(selector, className, message)`

Asserts that selected element(s) has the that and only that class name.

### `browser.assert.cookie(name, expected, message)`

Asserts that a cookie with the given name has the expected value.

### `browser.assert.element(selector, message)`

Assert that an element matching selector exists.

### `browser.assert.elements(selector, count, message)`

Assert how many elements exist that match the selector.

The count can be a number, or an object with the following properties:

- `atLeast` - Expect to find at least that many elements.
- `atMost`  - Expect to find at most that many elements.
- `exactly` - Expect to find exactly that many elements.

### `browser.assert.evaluate(expression, expected, message)`

Evaluates the JavaScript expression in the browser context.  With one argument,
asserts that the value is true.  With two or three arguments, asserts that the
value of the expression matches the expected value.

### `browser.assert.global(name, expected, message)`

Asserts that the global (window) property has the expected value.

### `browser.assert.hasClass(selector, className, message)`

Asserts that selected element(s) has the expected class name (it may have many
other class names).

### `browser.assert.hasFocus(selector, message)`

Asserts that selected element has the focus.

### `browser.assert.input(selector, expected, message)`

Asserts that selected input field (text field, text area, etc) has the expected
value.

### `browser.assert.hasNoClass(selector, className, message)`

Asserts that selected element(s) does not have the expected class name (it may
have many other class names).

### `browser.assert.prompted(messageShown, message)`

Assert that browser prompted with a given message.

### `browser.assert.redirected(message)`

Asserts that browser was redirected when retrieving the current page.

### `browser.assert.success(message)`

Assert that the last page load returned status code 200.

### `browser.assert.status(code, message)`

Assert that the last page load returned the expected status code.

### `browser.assert.style(selector, style, expected, message)`

Assert that the style property of the selected element(s) the expected value.

### `browser.assert.text(selector, expected, message)`

Assert that text content of selected element(s) matche the expected value.

### `browser.assert.url(url, message)`

Asserts that current page has the expected URL.

The expected URL value can be a string, regular expression, or function just
like every other assertion.  It can also be an object, in which case, individual
properties are matched against the URL.

For example:

```
browser.assert.url({ pathame: "/resource" });
browser.assert.url({ query: { name: "joedoe" } });
```

### Add Your Own Assertions

You can add more assertions by adding methods to the prototype of
`Browser.Assert`.  These have access to the browser as a property, for example:

```
// Asserts the browser has the expected number of open tabs.
Browser.Assert.prototype.openTabs = function(expected, message) {
  assert.equal(this.browser.tabs.length, expected, message);
};
```




## Events

### `console (level, messsage)`

Emitted whenever a message is printed to the console (`console.log`,
`console.error`, `console.trace`, etc).

The first argument is the logging level, one of `debug`, `error`, `info`, `log`,
`trace` or `warn`.  The second argument is the message to log.

### `active (window)`

Emitted when this window becomes the active window.

### `closed (window)`

Emitted when a window is closed.

### `done ()`

Emitted whenever the event loop is empty.

### `evaluated (code, result, filename)`

Emitted whenever JavaScript code is evaluated.  The first argument is the
JavaScript function or source code, the second argument the result, and the
third argument is the filename.

### `event (event, target)`

Emitted whenever a DOM event is fired on the target element, document or window.

### `focus (element)`

Emitted whenever an input element receives the focus.

### `inactive (window)`

Emitted when this window is no longer the active window.

### `interval (function, interval)`

Emitted whenever an interval event (`setInterval`) is fired, with the function and
interval.

### `link (url, target)`

Emitted when a link is clicked and the browser navigates to a new URL.  Includes
the URL and the target window (default to `_self`).

### `loaded (document)`

Emitted when a document is loaded into a window or frame.  This event is emitted
after the HTML is parsed and loaded into the Document object.

### `loading (document)`

Emitted when a document is loaded into a window or frame.  This event is emitted
with an empty Document object, before parsing the HTML response.

### `opened (window)`

Emitted when a window is opened.

### `redirect (request, response)`

Emitted when following a redirect.

The first argument is the request, the second argument is the redirect response.
The URL of the new resource to retrieve is given by `response.url`.

### `request (request, target)`

Emitted before making a request to retrieve the resource.

The first argument is the request object (see *Resources* for more details), the
second argument is the target element/document.

### `response (request, response, target)`

Emitted after receiving the response when retrieving a resource.

The first argument is the request object (see *Resources* for more details), the
second argument is the response that is passed back, and the third argument is
the target element/document.

### `submit (url, target)`

Emitted when a form is submitted.  Includes the action URL and the target window
(default to `_self`).

### `timeout (function, delay)`

Emitted whenever a timeout event (`setTimeout`) is fired, with the function and
delay.




## Resources

Zombie can retrieve with resources - HTML pages, scripts, XHR requests - over
HTTP, HTTPS and from the file system.

Most work involving resources is done behind the scenes, but there are few
notable features that you'll want to know about. Specifically, if you need to do
any of the following:

- Inspect the history of retrieved resources, useful for troubleshooting issues
  related to resource loading
- Simulate a failed server
- Change the order in which resources are retrieved, or otherwise introduce
  delays to simulate a real world network
- Mock responses from servers you don't have access to, or don't want to access
  from test environment
- Request resources directly, but have Zombie handle cookies, authentication,
  etc
- Implement new mechanism for retrieving resources, for example, add new
  protocols or support new headers


### The Resources List

Each browser provides access to its resources list through `browser.resources`.
This is an array of resources, and you can iterate and manipulate it just like
any other JS array.

Each resource provides four properties: `request`, `response`, `error` and
`target`.

The request object consists of:

- `method` - HTTP method, e.g. "GET"
- `url` - The requested URL
- `headers` - All request headers
- `body` - The request body can be Buffer or String, only applies to POST and
  PUT methods multiparty - Used instead of a body to support file upload
- `time` - Timestamp when request was made
- `timeout` - Request timeout (0 for no timeout)

The response object consists of:

- `url` - The actual URL of the resource. This may be different from the request
  URL after redirects.
- `statusCode` - HTTP status code, eg 200
- `statusText` - HTTP static code as text, eg "OK"
- `headers` - All response headers
- `body` - The response body, may be Buffer or String, depending on the content
  type
- `redirects` - Number of redirects followed
- `time` - Timestamp when response was completed

While a request is in progress, the resource entry would only contain the
`request` property. If an error occurred during the request, e.g the server was
down, the resource entry would contain an `error` property instead of `request`.

Request for loading pages and scripts include the target DOM element or
document. This is used internally, and may also give you more insight as to why
a request is being made.

The `target` property associates the resource with an HTML document or element
(only applies to some resources, like documents and scripts).

Use `browser.resources.dump()` to dump a list of all resources to the console.
This method accepts an optional output stream.


### Mocking, Failing and Delaying Responses

To help you in testing, you can use `browser.resources` to mock, fail or delay a
server response.

For example, to mock a response:

```
browser.resources.mock("http://3rd.party.api/v1/request", {
  statusCode: 200,
  headers:    { "ContentType": "application/json" },
  body:       JSON.stringify({ "count": 5 })
})
```

In the real world, servers and networks often fail.  You can test to for these
conditions by asking Zombie to simulate a failure.  For example:

```
browser.resource.fail("http://3rd.party.api/v1/request");
```

Use `mock` to simulate a server failing to process a request by returning status
code 500.  Use `fail` to simulate a server that is not accessible.

Another issue you'll encounter in real-life applications are network latencies.
When running a test suite, Zombie will request resources in the order in which
they appear on the page, and likely receive them from a local server in that
same order.

Occassionally you'll need to force the server to return resources in a different
order, for example, to check what happens when script A loads after script B.
You can introduce a delay into any response as simple as:

```
browser.resources.delay("http://3d.party.api/v1/request", 50);
```

Once you're done mocking, failing or delaying a resource, restore it to its
previous state:

```
browser.resources.restore("http://3d.party.api/v1/request");
```


### Operating On Resources

If you need to retrieve of operate on resources directly, you can do that as
well, using all the same features available to Zombie, including mocks, cookies,
authentication, etc.

The `browser.resources` object exposes `get`, `post` and the more generic
`request` method.

For example, to download a document:

```
browser.resources.get("http://some.service", function(error, response) {
  console.log(response.statusText);
  console.log(response.body);
});
```

```
var params  = { "count": 5 };
browser.resources.post("http://some.service", { params: params }, function(error, response) {
  . . .
});
```

```
var headers = { "Content-Type": "application/x-www-form-urlencoded" };
browser.resources.post("http://some.service", { headers: headers, body: "count=5" }, function(error, response) {
   . . .
});
```

```
browser.resources.request("DELETE", "http://some.service", function(error) {
  . . .
});
```


### The Resource Chain

Zombie uses a pipeline to operate on resources.  You can extend that pipeline
with your own set of handlers, for example, to support additional protocols,
content types, special handlers, better resource mocking, etc.

The pipeline consists of a set of filters.  There are two types of filters.
Functions with two arguments are request filters, they take a request object and
a callback.  The function then calls the callback with no arguments to pass
control to the next filter, with an error to stop processing, or with null and
a request object.

Functions with three arguments are response filters, they take a request object,
response object and callback.  The function then calls the callback with no
arguments to pass control to the next filter, or with an error to stop
processing.

To add a new filter at the end of the pipeline:

```
browser.resources.addFilter(function(request, next) {
  // Let's delay this request by 1/10th second
  setTimeout(function() {
    Resources.httpRequest(request, next);
  }, Math.random() * 100);
});
```

If you need anything more complicated, you can access the pipeline directly via
`browser.resources.filters`.

You can add filters to all browsers via `Browser.Resources.addFilter`.  These
filters are automatically added to every new `browser.resources` instance.

```
Browser.Resources.addFilter(function(request, response, next) {
  // Log the response body
  console.log("Response body: " + response.body);
  next();
});
```

That list of filters is available from `Browser.Resources.filters`.

When filters are executed, `this` is set to the browser instance.

