zombie.js-todo(7) -- Wishlist
=============================

* CSS support
  * Add `style` attribute, parsed on-demand
  * Add stylesheets to document
  * Add feature to load/parse internal and external stylesheets
  * Add browser option to control CSS loading (similar to `runScripts`)
  * Make sure `DOMContentLoaded` event fires after all stylesheets
    are loaded

* Navigation: Browser.open/close should work as a pair; look into supporting
  window.open; fire unload event when navigating away from page.

* Send unload event when navigating away from page.

* Time and timezone: within window context, new Date() should use browser clock
  and timezone; allow changing browser timezone and default to system's.

* Accessors for window.status.

* Support focus and blur events. 
