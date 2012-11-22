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

`created (browser)`

Emitted when a new browser instance is created.  Allows you to modify the
browser instance, e.g. add or modify supported features.

`opened (window)`

Emitted when a window is opened.

`closed (window)`

Emitted when a window is closed.

`active (window)`

Emitted when this window becomes the active window.

`inactive (window)`

Emitted when this window is no longer the active window.

`loaded (document)`

Emitted when a document is loaded into a window or frame.

`event (event, target)`

Emitted whenever a DOM event is fired on the target element, document or window.



The browser now acts as an EventEmitter and windows report a variety of events:
error - error reported
executed - script executed
prompt - user was prompted (alert, confirm, prompt)
xhr - XHR state change (open, loading and loaded)
timeout - timeout or interval fired
submit - form submitted

