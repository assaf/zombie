zombie.js-selectors(7) -- CSS Selectors
=======================================


Zombie.js uses [jsdom's](https://github.com/tmpvar/jsdom) choice of selector engine, currently [nwmatcher](http://javascript.nwbox.com/NWMatcher/) which provides support for many
[CSS 3 selectors](http://www.w3.org/TR/css3-selectors/) with a few useful
extension.

What follows is a list of CSS selectors currently supported in latest NWMatcher version (cloned from [https://github.com/dperini/nwmatcher/wiki/CSS-supported-selectors](https://github.com/dperini/nwmatcher/wiki/CSS-supported-selectors)).

Text and/or character selectors (content) have no meanings for applications, they don't work on element nodes but on text nodes, which do not provide an event interface.

### Universal selector

| Selector | Description |
|-|-|
| &#42; (asterisk) | any Element |

### Tag, Id and Class selectors
| Selector | Description |
|-|-|
| E | an Element of type E |
| E#fooId | an E element with ID equal to "fooId" |
| E.fooClass | an E element with CLASS equal to "fooClass" |

### Combinators selectors (child and siblings)

| Selector | Description |
|-|-|
| E F | an F element descendant child of an E element |
| E > F | an F element direct child of an E element |
| E + F | an F element immediately preceded by an E element |
| E ~ F | an F element preceded by an E element |

### Attribute selectors

| Selector | Description |
|-|-|
| E[foo] | an E element with a "foo" attribute |
| E[foo="bar"] | an E element whose "foo" attribute value is exactly equal to "bar" |
| E[foo^="bar"] | an E element whose "foo" attribute value begins exactly with the string "bar" |
| E[foo$="bar"] | an E element whose "foo" attribute value ends exactly with the string "bar" |
| E[foo*="bar"] | an E element whose "foo" attribute value contains the substring "bar" |
| E[foo~="bar"] | an E element whose "foo" attribute value is a list of whitespace-separated values, one of which is exactly equal to "bar" |
| E[foo&#124;="en"] | an E element whose "foo" attribute value is a hyphen-separated list of values beginning (from the left) with "en" |

### Structural pseudo-classes selectors

| Selector | Description |
|-|-|
| E:root | an E element, root of the document |
| E:empty | an E element that has no children (including text nodes) |
| E:nth-child(n) | an E element, the n-th child of its parent |
| E:nth-of-type(n) | an E element, the n-th sibling of its type |
| E:nth-last-child(n) | an E element, the n-th child of its parent, counting from the last one |
| E:nth-last-of-type(n) | an E element, the n-th sibling of its type, counting from the last one |
| E:first-child | an E element, first child of its parent |
| E:last-child | an E element, last child of its parent |
| E:only-child | an E element, only child of its parent |
| E:first-of-type | an E element, first sibling of its type |
| E:last-of-type | an E element, last sibling of its type |
| E:only-of-type | an E element, only sibling of its type |

### Negation pseudo-classes selector

| Selector | Description |
|-|-|
| E:not(s) | an E element that does not match simple selector s |

### Hyper-link, Target and Language pseudo-classes selectors

| Selector | Description |
|-|-|
| E:link | an E element being the source anchor of an hyper-link never visited |
| E:visited | an E element being the source anchor of an hyper-link already visited |
| E:target | an E element being the target of the referring URI |
| E:lang(it) | an E element having content in language "it" |

### User action pseudo-classes selectors

| Selector | Description |
|-|-|
| E:active | an E element during certain user actions |
| E:hover | an E element during a mouse over action |
| E:focus | an E element being the focus of the document |

### UI element state pseudo-classes selectors

| Selector | Description |
|-|-|
| E:enabled | an UI element E whose "disabled" property is set to false |
| E:disabled | an UI element E whose "disabled" property is set to true |
| E:checked | an UI element E whose "checked" or "selected" property is set to true ~(radio, checkbox, option)~ |

### WebForms and HTML5 support (optional external add-on)

| Selector | Description |
|-|-|
| E:indeterminate | an UI element E whose "indeterminate" property is set to true |
| E:default | an UI element E whose "defaultChecked" or "defaultSelected" properties are set to true |
| E:optional | an UI element E whose "required" property is set to false |
| E:required | an UI element E whose "required" property is set to true |
| E:invalid | an UI element E with constraint validation that do not satisfy its constraints |
| E:valid | an UI element E with constraint validation that satisfy its constraints |
| E:in-range | an UI element E with constraint validation not suffering for overflow or underflow |
| E:out-of-range | an UI element E with constraint validation suffering for overflow or underflow |
| E:read-only | an UI element E whose "readOnly" property is set to true |
| E:read-write | an UI element E whose "readOnly" property is set to false |

### Legacy support (optional external add-on)

| Selector | Description |
|-|-|
| E[foo!="bar"] | an E element whose "foo" attribute value is not exactly equal to "bar" |
| E:selected | an UI element E whose "selected" property is set to true (option) |
| E:contains() | an E element whose textual contents contain the given substring |

### Content pseudo-element selectors (not supported)

| Selector | Description |
|-|-|
| E::after | generated content after an E element |
| E::before | generated content before an E element |
| E::selection | portion of a document highlighted by the user |
| E::first-line | the first formatted line of an E element |
| E::first-letter | the first formatted letter of an E element |