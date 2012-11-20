## Assertions

Node.js core includes an `assert` function, and there are many alternatives you
can use for assertions and expectations.  Obviously Zombie will support all of
them.

To make your life easier, it also introduces a set of convenience assertions you
can execute directly against the browser object.  For example, to check that a
page load completed successfully, you may do:

  browser.assert.success();
  browser.assert.text("title", "My Awesome Site");
  browser.assert.element("#main");

Assertions that take an expected value, will compare that against the actual
value.  The expected value can be a primitive JavaScript value (string, number,
etc), a regular expression or a function.  In the later case, the function is
called with the actual value, and the assertion passes if the function returns
true.

Assertions that take a CSS selector use it to retrieve an HTML element or
elements.  You can also pass the element(s) directly instead of a selector (e.g.
if you need to access an element inside an iframe).

All assertions take an optional last argument that is the message to show if the
assertion fails, but when using frameworks that has good reporting (e.g. Mocha)
you want to let the assertion format the message for you.

The following assertions are available:

`browser.assert.attribute(selector, name, expected, message)`

Assert the named attribute of the selected element(s) has the expected value.
Fails if no elements found.

`browser.assert.cookie(name, expected, message)`

Asserts that a cookie with the given name has the expected value.

`browser.assert.css(selector, style, expected, message)`

Assert that the style property of the selected element(s) the expected value.

`browser.assert.element(selector, message)`

Assert that an element matching selector exists.

`browser.assert.elements(selector, count, message)`

Assert how many elements exist that match the selector.

The count can be a number, or an object with the following properties:

- `atLeast` - Expect to find at least that many elements.
- `atMost`  - Expect to find at most that many elements.
- `exactly` - Expect to find exactly that many elements.

`browser.assert.evaluate(expression, expected, message)`

Evaluates the JavaScript expression in the browser context.  With one argument,
asserts that the value is true.  With two or three arguments, asserts that the
value of the expression matches the expected value.

`browser.assert.global(name, expected, message)`

Asserts that the global (window) property has the expected value.

`browser.assert.inFocus(selector, message)`

Asserts that selected element has the focus.

`browser.assert.input(selector, expected, message)`

Asserts that selected input field (text field, text area, etc) has the expected
value.

`browser.assert.pathname(expected, message)`

Assert that document URL has the expected pathname.

`browser.assert.prompted(messageShown, message)`

Assert that browser prompted with a given message.

`browser.assert.redirected(message)`

Asserts that browser was redirected when retrieving the current page.

`browser.assert.success(message)`

Assert that the last page load returned status code 200.

`browser.assert.status(code, message)`

Assert that the last page load returned the expected status code.

`browser.assert.text(selector, expected, message)`

Assert that text content of selected element(s) matche the expected value.

`browser.assert.url(url, message)`

Asserts that current page has the expected URL.


You can add more assertions by adding methods to the prototype of
`Browser.Assert`.  These have access to the browser as a property, for example:

  // Asserts the browser has the expected number of open tabs.
  Browser.Assert.prototype.openTabs = function(expected, message) {
    assert.equal(this.browser.tabs.length, expected, message);
  };

