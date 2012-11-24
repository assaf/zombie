## Events

`console (level, messsage)`

Emitted whenever a message is printed to the console (`console.log`,
`console.error`, `console.trace`, etc).

The first argument is the logging level, one of `debug`, `error`, `info`, `log`,
`trace` or `warn`.  The second argument is the message to log.


`error (error)`
...

`log (messsage)`

browser.log


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



### Global Events

`Browser.events` is a global event sink.  All browser instances forward some
events to it, in particular the `console`, `error` and `log` events.

In addition, it handles the following events.

`active (window)`

Emitted when this window becomes the active window.

`closed (window)`

Emitted when a window is closed.

`created (browser)`

Emitted when a new browser instance is created.  Allows you to modify the
browser instance, e.g. add or modify supported features.

`done ()`

Emitted whenever the event loop is empty.

`event (event, target)`

Emitted whenever a DOM event is fired on the target element, document or window.

`focus (element)`

Emitted whenever an input element receives the focus.

`evaluated (code, result, filename)`

Emitted whenever JavaScript code is evaluated.  The first argument is the
JavaScript function or source code, the second argument the result, and the
third argument is the filename.

`inactive (window)`

Emitted when this window is no longer the active window.

`interval (function, interval)`

Emitted whenever an interval event (`setInterval`) is fired, with the function and
interval.

`loaded (document)`

Emitted when a document is loaded into a window or frame.  This event is emitted
after the HTML is parsed and loaded into the Document object.

`loading (document)`

Emitted when a document is loaded into a window or frame.  This event is emitted
with an empty Document object, before parsing the HTML response.

`opened (window)`

Emitted when a window is opened.

`timeout (function, delay)`

Emitted whenever a timeout event (`setTimeout`) is fired, with the function and
delay.



The browser now acts as an EventEmitter and windows report a variety of events:
error - error reported
executed - script executed
prompt - user was prompted (alert, confirm, prompt)
xhr - XHR state change (open, loading and loaded)
timeout - timeout or interval fired
submit - form submitted

