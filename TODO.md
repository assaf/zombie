zombie.js-todo(7) -- Wishlist
=============================

* CSS support
  * Add `style` attribute, parsed on-demand
  * Add stylesheets to document
  * Add feature to load/parse internal and external stylesheets
  * Add browser option to control CSS loading (similar to `runScripts`)
  * Make sure `DOMContentLoaded` event fires after all stylesheets
    are loaded

* New script context
  * The execution context for all scripts on the page is the `Window`
    object itself
  * Node's `runInContext` accepts a sandbox, then creates an actual V8
    context by copying properties to/from, which breaks asynchronous
    scripts (timer, XHR, etc) which run in the contex, not the sandbox

* Navigation: Browser.open/close should work as a pair; look into supporting
  window.open; fire unload event when navigating away from page.

* Send unload event when navigating away from page.

* Time and timezone: within window context, new Date() should use browser clock
  and timezone; allow changing browser timezone and default to system's.

* Accessors for window.status.

* Accessor for HTTP status from last request, also pass back to visit method callback

* Accessor to determine if last request was a redirect.

* Support focus and blur events. 
