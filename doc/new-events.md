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





`console (level, messsage)`
`error (error)`
`log (messsage)`




The browser now acts as an EventEmitter and windows report a variety of events:
open - new window opened (also iframe and when navigating)
closed - window closed
loading - document is loading into window
loaded - document loaded
missing - document not found
active - window became active (tab or history change)
inactive - window became inactive
event - event fired on the window/document
error - error reported
executed - script executed
console - message sent to console
prompt - user was prompted (alert, confirm, prompt)
storage - change to local or session storage
cookie - change to a cookie value
xhr - XHR state change (open, loading and loaded)
timeout - timeout or interval fired
submit - form submitted


Each browser is also an event emitter and you can listen to different lifecycle events and act on these. Events are different from hooks. Hooks are synchronous, your code executes before the next action. Events are asynchronous, they fire after the fact.

Still they are mighty useful, especially for instrumenting the browser and troubleshooting issues. For example, if you wanted to list all page loads you could do this:

Or to watch all timers as they fire, you could do this:

If you wanted to send all console.log messages to a log file, or format them differently for your CI server log you could do this:

