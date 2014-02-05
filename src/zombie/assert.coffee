# Browser assertions convenience.

assert        = require("assert")
{ isRegExp }  = require("util")
URL           = require("url")


# Used to assert that actual matches expected value, where expected may be a function or a string.
assertMatch = (actual, expected, message)->
  if isRegExp(expected)
    assert expected.test(actual), message || "Expected '#{actual}' to match #{expected}"
  else if typeof(expected) == "function"
    assert expected(actual), message
  else
    assert.deepEqual actual, expected, message


class Assert
  constructor: (@browser)->

  # -- Location/response --

  # Asserts that a cookie with the given name has the expected value.
  #
  # identifier - Cookie name or name/domain/path (see getCookie)
  # expected   - Expected value (null to test cookie is not set)
  # message    - Assert message if cookie does not have expected value
  cookie: (identifier, expected, message)->
    if arguments.length == 1
      expected = null
    actual = @browser.getCookie(identifier)
    message ||= "Expected cookie #{JSON.stringify(identifier)} to have the value '#{expected}', found '#{actual}'"
    assertMatch actual, expected, message

  # Asserts that browser was redirected when retrieving the current page.
  redirected: (message)->
    assert @browser.redirected, message

  # Assert that the last page load returned the expected status code.
  status: (code, message)->
    assert.equal @browser.statusCode, code, message

  # Assert that the last page load returned status code 200.
  success: (message)->
    assert @browser.success, message

  # Asserts that current page has the expected URL.
  #
  # Expected value can be a String, RegExp, Function or an object, in which case
  # object properties are tested against the actual URL (e.g. pathname, host,
  # query).
  url: (expected, message)->
    if typeof(expected) == "string" || isRegExp(expected) || typeof(expected) == "function"
      assertMatch @browser.location.href, expected, message
    else
      url = URL.parse(@browser.location.href, true)
      for key, value of expected
        # Gracefully handle default values, e.g. document.location.hash for
        # "/foo" is "" not null, not undefined.
        if key == "port"
          defaultValue = 80
        else
          defaultValue = null
        assertMatch url[key] || defaultValue, value || defaultValue, message


  # -- Document contents --

  # Assert the named attribute of the selected element(s) has the expected value.
  attribute: (selector, name, expected, message)->
    if arguments.length == 2
      expected = null
    elements = @browser.queryAll(selector)
    assert elements.length > 0, "Expected selector '#{selector}' to return one or more elements"
    for element in elements
      actual = element.getAttribute(name)
      assertMatch actual, expected, message

  # Assert that element matching selector exists.
  element: (selector, message)->
    @elements(selector, exactly: 1, message)

  # Assert how many elements matching selector exist.
  #
  # Count can be an exact number, or an object with the properties:
  # atLeast - Expect to find at least that many elements
  # atMost  - Expect to find at most that many elements
  # exactly - Expect to find exactly that many elements
  #
  # If count is unspecified, defaults to at least one.
  elements: (selector, count, message)->
    elements = @browser.queryAll(selector)
    if arguments.length == 1
      count = { atLeast: 1 }
    if count.exactly
      count = count.exactly
    if typeof(count) == "number"
      message ||= "Expected #{count} elements matching '#{selector}', found #{elements.length}"
      assert.equal elements.length, count, message
    else
      if count.atLeast
        elements = @browser.queryAll(selector)
        message ||= "Expected at least #{count.atLeast} elements matching '#{selector}', found only #{elements.length}"
        assert elements.length >= count.atLeast, message
      if count.atMost
        message ||= "Expected at most #{count.atMost} elements matching '#{selector}', found #{elements.length}"
        assert elements.length <= count.atMost, message

  # Asserts the selected element(s) has the expected CSS class.
  hasClass: (selector, expected, message)->
    elements = @browser.queryAll(selector)
    assert elements.length > 0, "Expected selector '#{selector}' to return one or more elements"
    for element in elements
      classNames = element.className.split(/\s+/)
      assert ~classNames.indexOf(expected),
        message || "Expected element '#{selector}' to have class #{expected}, found #{classNames.join(", ")}"

  # Asserts the selected element(s) doest not have the expected CSS class.
  hasNoClass: (selector, expected, message)->
    elements = @browser.queryAll(selector)
    assert elements.length > 0, "Expected selector '#{selector}' to return one or more elements"
    for element in elements
      classNames = element.className.split(/\s+/)
      assert classNames.indexOf(expected) == -1,
        message || "Expected element '#{selector}' to not have class #{expected}, found #{classNames.join(", ")}"

  # Asserts the selected element(s) has the expected class names.
  className: (selector, expected, message)->
    elements = @browser.queryAll(selector)
    assert elements.length > 0, "Expected selector '#{selector}' to return one or more elements"
    expected = expected.split(/\s+/).sort().join(" ")
    for element in elements
      actual = element.className.split(/\s+/).sort().join(" ")
      assertMatch actual, expected, 
        message || "Expected element '#{selector}' to have class #{expected}, found #{actual}"

  # Asserts the selected element(s) has the expected value for the named style
  # property.
  style: (selector, style, expected, message)->
    if arguments.length == 2
      expected = null
    elements = @browser.queryAll(selector)
    assert elements.length > 0, "Expected selector '#{selector}' to return one or more elements"
    for element in elements
      actual = element.style[style]
      assertMatch actual, expected,
        message || "Expected element '#{selector}' to have style #{style} value of #{expected}, found #{actual}"

  # Asserts that selected input field (text field, text area, etc) has the expected value.
  input: (selector, expected, message)->
    if arguments.length == 1
      expected = null
    elements = @browser.queryAll(selector)
    assert elements.length > 0, "Expected selector '#{selector}' to return one or more elements"
    for element in elements
      assertMatch element.value, expected, message

  # Asserts that a link exists with the given text and URL.
  link: (selector, text, url, message)->
    url = URL.resolve(@browser.location.href, url)
    elements = @browser.queryAll(selector)
    assert elements.length > 0, "Expected selector '#{selector}' to return one or more elements"
    matching = elements.filter (element)->
      element.textContent.trim() == text && element.href == url
    assert matching.length > 0, "Expected at least one link matching the given text and URL"


  # Assert that text content of selected element(s) matches expected string.
  #
  # You can also call this with a regular expression, or a function.
  text: (selector, expected, message)->
    elements = @browser.queryAll(selector)
    assert elements.length > 0, "Expected selector '#{selector}' to return one or more elements"
    actual = elements.map((e)-> e.textContent).join("").trim().replace(/\s+/g, " ")
    assertMatch actual, expected || "", message


  # -- Window --

  # Asserts that selected element has the focus.
  hasFocus: (selector, message)->
    if selector
      elements = @browser.queryAll(selector)
      assert.equal elements.length, 1, "Expected selector '#{selector}' to return one element"
      assert.equal @browser.activeElement, elements[0], "Expected element '#{selector}' to have the focus'"
    else
      assert.equal @browser.activeElement, @browser.body, "Expected no element to have focus"


  # -- JavaScript --

  # Evaluates Javascript expression and asserts value.  With one argument,
  # asserts that the expression evaluates to (JS) true.
  evaluate: (expression, expected, message)->
    actual = @browser.evaluate(expression)
    if arguments.length == 1
      assert actual
    else
      assertMatch actual, expected, message

  # Asserts that the global (window) property name has the expected value.
  global: (name, expected, message)->
    actual = @browser.window[name]
    if arguments.length == 1
      assert actual
    else
      message ||= "Expected global #{name} to have the value '#{expected}', found '#{actual}'"
      assertMatch actual, expected, message

  # Assert that browser prompted with a given message.
  prompted: (messageShown, message)->
    assert @browser.prompted(messageShown), message


 module.exports = Assert
