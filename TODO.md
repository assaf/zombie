- Use HTML5 parser (see https://github.com/aredridel/html5)

  HTML5 parser can deal with many more documents (e.g. missing html/body
  elements) than html-parser, and obviously new HTML5 elements.

  Unfortunately, it adds script elements to the DOM before adding their text
  content; JSDOM listens to the DOMNodeInsertedIntoDocument event, which is
  fired on empty script element.

- brower.location set should evaluate javascript: links
- Browser open should create new window
- Browser close should close existing window
- Send unload event when loading new page
- Browser.clock should be set from current time
- Date should use browser clock
- Allow setting of timezone in browser
- Allow setting of user agent in browser
- Browser sends user agent on download/XHR
- Handle confirm/alert
- Mock resources
