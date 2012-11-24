## Events

`console (level, messsage)`

Emitted whenever a message is printed to the console (`console.log`,
`console.error`, `console.trace`, etc).

The first argument is the logging level, one of `debug`, `error`, `info`, `log`,
`trace` or `warn`.  The second argument is the message to log.



`active (window)`

Emitted when this window becomes the active window.

`closed (window)`

Emitted when a window is closed.


`done ()`

Emitted whenever the event loop is empty.

`evaluated (code, result, filename)`

Emitted whenever JavaScript code is evaluated.  The first argument is the
JavaScript function or source code, the second argument the result, and the
third argument is the filename.

`event (event, target)`

Emitted whenever a DOM event is fired on the target element, document or window.

`focus (element)`

Emitted whenever an input element receives the focus.

`inactive (window)`

Emitted when this window is no longer the active window.

`interval (function, interval)`

Emitted whenever an interval event (`setInterval`) is fired, with the function and
interval.

`link (url, target)`

Emitted when a link is clicked and the browser navigates to a new URL.  Includes
the URL and the target window (default to `_self`).

`loaded (document)`

Emitted when a document is loaded into a window or frame.  This event is emitted
after the HTML is parsed and loaded into the Document object.

`loading (document)`

Emitted when a document is loaded into a window or frame.  This event is emitted
with an empty Document object, before parsing the HTML response.

`opened (window)`

Emitted when a window is opened.

`redirect (request, response)`

Emitted when following a redirect.

The first argument is the request, the second argument is the redirect response.
The URL of the new resource to retrieve is given by `response.url`.

`request (request, target)`

Emitted before making a request to retrieve the resource.

The first argument is the request object (see *Resources* for more details), the
second argument is the target element/document.

`response (request, response, target)`

Emitted after receiving the response when retrieving a resource.

The first argument is the request object (see *Resources* for more details), the
second argument is the response that is passed back, and the third argument is
the target element/document.

`submit (url, target)`

Emitted when a form is submitted.  Includes the action URL and the target window
(default to `_self`).

`timeout (function, delay)`

Emitted whenever a timeout event (`setTimeout`) is fired, with the function and
delay.



Browser.extend(function(browser) {
  browser.on("console", function(level, message) {
    logger.log(message);
  });
  browser.on("log", function(level, message) {
    logger.log(message);
  });
});
