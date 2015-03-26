// Browser assertions convenience.

const assert        = require('assert');
const { isRegExp }  = require('util');
const URL           = require('url');
const Utils         = require('jsdom/lib/jsdom/utils');


// Used to assert that actual matches expected value, where expected may be a function or a string.
function assertMatch(actual, expected, message) {
  if (isRegExp(expected))
    assert(expected.test(actual), message || `Expected '${actual}' to match ${expected}`);
  else if (typeof expected === 'function')
    assert(expected(actual), message);
  else
    assert.deepEqual(actual, expected, message);
}


module.exports = class Assert {

  constructor(browser) {
    this.browser = browser;
  }


  // -- Location/response --

  // Asserts that a cookie with the given name has the expected value.
  //
  // identifier - Cookie name or name/domain/path (see getCookie)
  // expected   - Expected value (null to test cookie is not set)
  // message    - Assert message if cookie does not have expected value
  cookie(identifier, expected = null, message = null) {
    const actual = this.browser.getCookie(identifier);
    assertMatch(actual, expected,
                message || `Expected cookie ${JSON.stringify(identifier)} to have the value '${expected}', found '${actual}'`);
  }

  // Asserts that browser was redirected when retrieving the current page.
  redirected(message) {
    assert(this.browser.redirected, message);
  }

  // Assert that the last page load returned the expected status code.
  status(code, message) {
    assert.equal(this.browser.statusCode, code, message);
  }

  // Assert that the last page load returned status code 200.
  success(message) {
    assert(this.browser.success, message);
  }

  // Asserts that current page has the expected URL.
  //
  // Expected value can be a String, RegExp, Function or an object, in which case
  // object properties are tested against the actual URL (e.g. pathname, host,
  // query).
  url(expected, message) {
    if (typeof expected === 'string') {
      const absolute = Utils.resolveHref(this.browser.location.href, expected);
      assertMatch(this.browser.location.href, absolute, message);
    } else if (isRegExp(expected) || typeof expected === 'function')
      assertMatch(this.browser.location.href, expected, message);
    else {
      const url = URL.parse(this.browser.location.href, true);
      for (let key in expected) {
        let value = expected[key];
        // Gracefully handle default values, e.g. document.location.hash for
        // "/foo" is "" not null, not undefined.
        let defaultValue = (key === 'port') ? 80 : null;
        assertMatch(url[key] || defaultValue, value || defaultValue, message);
      }
    }
  }


  // -- Document contents --

  // Assert the named attribute of the selected element(s) has the expected value.
  attribute(selector, name, expected = null, message = null) {
    const elements = this.browser.queryAll(selector);
    assert(elements.length, `Expected selector '${selector}' to return one or more elements`);
    for (let element of elements) {
      let actual = element.getAttribute(name);
      assertMatch(actual, expected, message);
    }
  }

  // Assert that element matching selector exists.
  element(selector, message) {
    this.elements(selector, { exactly: 1 }, message);
  }

  // Assert how many elements matching selector exist.
  //
  // Count can be an exact number, or an object with the properties:
  // atLeast - Expect to find at least that many elements
  // atMost  - Expect to find at most that many elements
  // exactly - Expect to find exactly that many elements
  //
  // If count is unspecified, defaults to at least one.
  elements(selector, count, message) {
    const elements = this.browser.queryAll(selector);
    if (arguments.length === 1)
      this.elements(selector, { atLeast: 1});
    else if (Number.isInteger(count))
      this.elements(selector, { exactly: count }, message);
    else {
      if (count.exactly)
        assert.equal(elements.length, count.exactly,
                     message || `Expected ${count.exactly} elements matching '${selector}', found ${elements.length}`);
      if (count.atLeast)
        assert(elements.length >= count.atLeast,
               message || `Expected at least ${count.atLeast} elements matching '${selector}', found only ${elements.length}`);
      if (count.atMost)
        assert(elements.length <= count.atMost,
               message || `Expected at most ${count.atMost} elements matching '${selector}', found ${elements.length}`);
    }
  }

  // Asserts the selected element(s) has the expected CSS class.
  hasClass(selector, expected, message) {
    const elements = this.browser.queryAll(selector);
    assert(elements.length, `Expected selector '${selector}' to return one or more elements`);
    for (let element of elements) {
      let classNames = element.className.split(/\s+/);
      assert(~classNames.indexOf(expected),
             message || `Expected element '${selector}' to have class ${expected}, found ${classNames.join(', ')}`);
    }
  }

  // Asserts the selected element(s) doest not have the expected CSS class.
  hasNoClass(selector, expected, message) {
    const elements = this.browser.queryAll(selector);
    assert(elements.length, `Expected selector '${selector}' to return one or more elements`);
    for (let element of elements) {
      let classNames = element.className.split(/\s+/);
      assert(classNames.indexOf(expected) === -1,
             message || `Expected element '${selector}' to not have class ${expected}, found ${classNames.join(', ')}`);
    }
  }

  // Asserts the selected element(s) has the expected class names.
  className(selector, expected, message) {
    const elements = this.browser.queryAll(selector);
    assert(elements.length, `Expected selector '${selector}' to return one or more elements`);
    const array    = expected.split(/\s+/).sort().join(' ');
    for (let element of elements) {
      let actual = element.className.split(/\s+/).sort().join(' ');
      assertMatch(actual, array,
                  message || `Expected element '${selector}' to have class ${expected}, found ${actual}`);
    }
  }

  // Asserts the selected element(s) has the expected value for the named style
  // property.
  style(selector, style, expected = null, message = null) {
    const elements = this.browser.queryAll(selector);
    assert(elements.length, `Expected selector '${selector}' to return one or more elements`);
    for (let element of elements) {
      let actual = element.style.getPropertyValue(style);
      assertMatch(actual, expected,
                  message || `Expected element '${selector}' to have style ${style} value of ${expected}, found ${actual}`);
    }
  }

  // Asserts that selected input field (text field, text area, etc) has the expected value.
  input(selector, expected = null, message = null) {
    const elements = this.browser.queryAll(selector);
    assert(elements.length, `Expected selector '${selector}' to return one or more elements`);
    for (let element of elements)
      assertMatch(element.value, expected, message);
  }

  // Asserts that a link exists with the given text and URL.
  link(selector, text, url, message) {
    const elements = this.browser.queryAll(selector);
    assert(elements.length, message || `Expected selector '${selector}' to return one or more elements`);
    const matchingText = elements.filter(element => element.textContent.trim() === text);
    if (isRegExp(url)) {
      const matchedRegexp = matchingText.filter(element => url.test(element.href));
      assert(matchedRegexp.length, message || `Expected at least one link matching the given text and URL`);
    } else {
      const absolute    = Utils.resolveHref(this.browser.location.href, url);
      const matchedURL  = matchingText.filter(element => element.href === absolute);
      assert(matchedURL.length, message || `Expected at least one link matching the given text and URL`);
    }
  }


  // Assert that text content of selected element(s) matches expected string.
  //
  // You can also call this with a regular expression, or a function.
  text(selector, expected, message) {
    const elements = this.browser.queryAll(selector);
    assert(elements.length, `Expected selector '${selector}' to return one or more elements`);
    const actual = elements
      .map(elem => elem.textContent)
      .join('')
      .trim()
      .replace(/\s+/g, ' ');
    assertMatch(actual, expected || '', message);
  }


  // -- Window --

  // Asserts that selected element has the focus.
  hasFocus(selector, message) {
    if (selector) {
      const elements = this.browser.queryAll(selector);
      assert.equal(elements.length, 1,
                   message || `Expected selector '${selector}' to return one element`);
      assert.equal(this.browser.activeElement, elements[0],
                   message || `Expected element '${selector}' to have the focus'`);
    } else
      assert.equal(this.browser.activeElement, this.browser.body,
                   message || 'Expected no element to have focus');
  }


  // -- JavaScript --

  // Evaluates Javascript expression and asserts value.  With one argument,
  // asserts that the expression evaluates to (JS) true.
  evaluate(expression, expected, message) {
    const actual = this.browser.evaluate(expression);
    if (arguments.length === 1)
      assert(actual);
    else
      assertMatch(actual, expected, message);
  }

  // Asserts that the global (window) property name has the expected value.
  global(name, expected, message) {
    const actual = this.browser.window[name];
    if (arguments.length === 1)
      assert(actual);
    else
      assertMatch(actual, expected,
                  message || `Expected global ${name} to have the value '${expected}', found '${actual}'`);
  }

};

