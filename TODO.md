TODO
====

* Use HTML5 parser (see https://github.com/aredridel/html5)

  HTML5 parser can deal with many more documents (e.g. missing html/body
  elements) than html-parser, and obviously new HTML5 elements.

  Unfortunately, it adds script elements to the DOM before adding their text
  content; JSDOM listens to the DOMNodeInsertedIntoDocument event, which is
  fired on empty script element.

* Navigation: Browser.open/close should work as a pair; look into supporting
  window.open; fire unload event when navigating away from page.

* Send unload event when navigating away from page.

* Time and timezone: within window context, new Date() should use browser clock
  and timezone; allow changing browser timezone and default to system's.

* User agent: allow setting of user agent; brower sends user agent in all
  requests (pages, forms and XHR).

* Prompts: handle window.confirm and window.alert.

* Enhance DOM with find/filter/html/text methods on elements and node lists.

* More documentation.
