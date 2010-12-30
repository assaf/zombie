zombie.js-todo(7) -- Wishlist
=============================

* Navigation: Browser.open/close should work as a pair; look into supporting
  window.open; fire unload event when navigating away from page.

* Send unload event when navigating away from page.

* Time and timezone: within window context, new Date() should use browser clock
  and timezone; allow changing browser timezone and default to system's.

* User agent: allow setting of user agent; brower sends user agent in all
  requests (pages, forms and XHR).

* Prompts: handle window.confirm and window.alert.
