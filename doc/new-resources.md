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

  browser.resources.mock("http://3rd.party.api/v1/request", {
    statusCode: 200,
    headers:    { "ContentType": "application/json" },
    body:       JSON.stringify({ "count": 5 })
  })

In the real world, servers and networks often fail.  You can test to for these
conditions by asking Zombie to simulate a failure.  For example:

  browser.resource.fail("http://3rd.party.api/v1/request");

Use `mock` to simulate a server failing to process a request by returning status
code 500.  Use `fail` to simulate a server that is not accessible.

Another issue you'll encounter in real-life applications are network latencies.
When running a test suite, Zombie will request resources in the order in which
they appear on the page, and likely receive them from a local server in that
same order.

Occassionally you'll need to force the server to return resources in a different
order, for example, to check what happens when script A loads after script B.
You can introduce a delay into any response as simple as:

  browser.resources.delay("http://3d.party.api/v1/request", 50);

Once you're done mocking, failing or delaying a resource, restore it to its
previous state:

  browser.resources.restore("http://3d.party.api/v1/request");


### Operating On Resources

If you need to retrieve of operate on resources directly, you can do that as
well, using all the same features available to Zombie, including mocks, cookies,
authentication, etc.

The `browser.resources` object exposes `get`, `post` and the more generic
`request` method.

For example, to download a document:

  browser.resources.get("http://some.service", function(error, response) {
    console.log(response.statusText);
    console.log(response.body);
  });

  var params  = { "count": 5 };
  browser.resources.post("http://some.service", { params: params }, function(error, response) {
    . . .
  });

  var headers = { "Content-Type": "application/x-www-form-urlencoded" };
  browser.resources.post("http://some.service", { headers: headers, body: "count=5" }, function(error, response) {
     . . .
  });

  browser.resources.request("DELETE", "http://some.service", function(error) {
    . . .
  });


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

  browser.resources.addFilter(function(request, next) {
    // Let's delay this request by 1/10th second
    setTimeout(function() {
      Resources.httpRequest(request, next);
    }, Math.random() * 100);
  });

If you need anything more complicated, you can access the pipeline directly via
`browser.resources.filters`.

You can add filters to all browsers via `Browser.Resources.addFilter`.  These
filters are automatically added to every new `browser.resources` instance.  They
are also bound to `browser.resources`:

  Browser.Resources.addFilter(function(request, response, next) {
    // Log the response body
    console.log("Response body: " + response.body);
    next();
  });

That list of filters is available from `Browser.Resources.filters`.
