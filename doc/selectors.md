zombie.js-selectors(7) -- CSS Selectors
=======================================


Zombie.js uses [Sizzle.js](http://sizzlejs.com/) which provides support for most
[CSS 3 selectors](http://www.w3.org/TR/css3-selectors/) with a few useful
extension.

Sizzle.js is the selector engine used in jQuery, so if you're familiar
with jQuery selectors, you're familiar with Sizzle.js.

The following list summarizes which selectors are currently
supported:

`*` Any element

`E` An element of type E

`E#myid` An E element with ID equal to "myid"

`E.foo` An E element whose class is "foo"

`E[foo]` An E element with a "foo" attribute

`E[foo="bar"]` An E element whose "foo" attribute value is exactly equal to "bar"

`E[foo!="bar"]` An E element whose "foo" attribute value does not equal to "bar"

`E[foo~="bar"]` An E element whose "foo" attribute value is a list of whitespace-separated values, one of which is exactly equal to "bar"

`E[foo^="bar"]` An E element whose "foo" attribute value begins exactly with the string "bar"

`E[foo$="bar"]` An E element whose "foo" attribute value ends exactly with the string "bar"

`E[foo*="bar"]` An E element whose "foo" attribute value contains the substring "bar"

`E[foo|="en"]` An E element whose "foo" attribute has a hyphen-separated list of values beginning (from the left) with "en"

`E:nth-child(n)`  An E element, the n-th child of its parent

`E:first-child`  An E element, first child of its parent

`E:last-child`  An E element, last child of its parent

`E:only-child`  An E element, only child of its parent

`E:empty` An E element that has no children (including text nodes)

`E:link` A link

`E:focus` An E element during certain user actions

`E:enabled` A user interface element E which is enabled

`E:disabled` A user interface element E which is disabled

`E:checked` A user interface element E which is checked (for instance a radio-button or checkbox)

`E:input` An E element that is an input element (includes `textarea`, `select` and `button`)

`E:text` An E element that is an input text field or text area

`E:checkbox` An E element that is an input checkbox

`E:file` An E element that is an input file

`E:password` An E element that is an input password

`E:submit` An E element that is an input or button of type `submit`

`E:image` An E element that is an input of type `image`

`E:button` An E element that is an input or button of type `button`

`E:reset` An E element that is an input or button of type `reset`

`E:header` An header element, one of h1, h2, h3, h4, h5, h6

`E:parent` A parent element, an element that contains another element

`E:not(s)` An E element that does not match the selector `s` (multiple selectors supported)

`E:contains(t)` An E element whose textual contents contains `t` (case sensitive)

`E:first` An E element whose position on the page is first in document order

`E:last` An E element whose position on the page is last in document order

`E:even` An E element whose position on the page is even numbered (counting starts at 0)

`E:odd` An E element whose position on the page is odd numbered (counting starts at 0)

`E:eq(n)/:nth(n)` An E element whose Nth element on the page (e.g `:eq(5)`)

`E:lt(n)` An E element whose position on the page is less than `n`

`E:gt(n)` An E element whose position on the page is less than `n`

`E F` An F element descendant of an E element

`E > F` An F element child of an E element

`E + F` An F element immediately preceded by an E element

`E ~ F` An F element preceded by an E element

