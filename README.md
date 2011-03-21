zombie.js(1) -- Insanely fast, headless full-stack testing using Node.js
========================================================================


## The Bite

If you're going to write an insanely fast, headless browser, how can you not
call it Zombie?  Zombie it is.

Zombie.js is a lightweight framework for testing client-side JavaScript code in
a simulated environment.  No browser required.

Let's try to sign up to a page and see what happens:

    var zombie = require("zombie");
    var assert = require("assert");

    // Load the page from localhost
    zombie.visit("http://localhost:3000/", function (err, browser, status) {

      // Fill email, password and submit form
      browser.
        fill("email", "zombie@underworld.dead").
        fill("password", "eat-the-living").
        pressButton("Sign Me Up!", function(err, browser, status) {

          // Form submitted, new page loaded.
          assert.equal(browser.text("title"), "Welcome To Brains Depot");

        })

    });

Well, that was easy.


## Walking

To start off we're going to need a browser.  A browser maintains state
across requests: history, cookies, HTML 5 local and session stroage.  A
browser has a main window, and typically a document loaded into that
window.

You can create a new `zombie.Browser` and point it at a document, either
by setting the `location` property or calling its `visit` function.  As
a shortcut, you can just call the `zombie.visit` function with a URL and
callback.

The browser will load the document and if the document includes any
scripts, also load and execute these scripts.  It will then process some
events, for example, anything your scripts do on page load.  All of
that, just like a real browser, happens asynchronously.

To wait for the page to fully load and all events to fire, you pass
`visit` a callback function.  This function takes two arguments.  If
everything is successful (page loaded, events run), the callback is
called with `null` and a reference to the browser.  If anything went
wrong (page not loaded, event errors), the callback is called with an
error.

If you worked with Node.js before you're familiar with this callback
pattern.  Every time you see a callback in the Zombie.js API, it works
that way: the first argument is an error, or null if there is no error.
And if there are no errors, the remaining arguments may hold interesting
values.

For example, the callback you pass to `visit` receives the browser as
the second argument and HTTP status code as the third argument.

Whenever you want to wait for all events to be processed, just call
`browser.wait` with a callback.

Read more [on the Browser API](api)


## Hunting

There are several ways you can inspect the contents of a document.  For
starters, there's the [DOM API](http://www.w3.org/DOM/DOMTR), which you
can use to find elements and traverse the document tree.

You can also use CSS selectors to pick a specific element or node list.
Zombie.js implements the [DOM Selector
API](http://www.w3.org/TR/selectors-api/).  These functions are
available from every element, the document, and the `Browser` object
itself.

To get the HTML contents of an element, read its `innerHTML` property.
If you want to include the element itself with its attributes, read the
element's `outerHTML` property instead.  Alternatively, you can call the
`browser.html` function with a CSS selector and optional context
element.  If the function selects multiple elements, it will return the
combined HTML of them all.

To see the textual contents of an element, read its `textContent`
property.  Alternatively, you can call the `browser.text` function with
a CSS selector and optional context element.  If the function selects
multiple elements, it will return the combined text contents of them
all.

Here are a few examples for checking the contents of a document:

    // Make sure we have an element with the ID brains.
    assert.ok(browser.querySelector("#brains"));

    // Make sure body has two elements with the class hand.
    assert.equal(browser.body.querySelectorAll(".hand").length, 2);

    // Check the document title.
    assert.equal(browser.text("title"), "The Living Dead");

    // Show me the document contents.
    console.log(browser.html());

    // Show me the contents of the parts table:
    console.log(browser.html("table.parts"));

CSS selectors are implemented by Sizzle.js.  In addition to CSS 3
selectors you get additional and quite useful extensions, such as
`:not(selector)`, `[NAME!=VALUE]`, `:contains(TEXT)`, `:first/:last` and
so forth.  Check out the [Sizzle.js
documentation](https://github.com/jeresig/sizzle/wiki) for more details.

Read more [on the Browser API](api) and [CSS
selectors](selectors)



## Feeding

You're going to want to perform some actions, like clicking links,
entering text, submitting forms.  You can certainly do that using the
[DOM API](http://www.w3.org/DOM/DOMTR), or several of the convenience
functions we're going to cover next.

To click a link on the page, use `clickLink` with selector and callback.
The first argument can be a CSS selector (see _Hunting_), the `A`
element, or the text contents of the `A` element you want to click.

The second argument is a callback, which much like the `visit` callback
gets fired after all events are processed, with either an error, or
`null`, the browser and the HTTP status code.

Let's see that in action:

    // Now go to the shopping cart page and check that we have
    // three bodies there.
    browser.clickLink("View Cart", function(err, browser, status) {
      assert.equal(browser.querySelectorAll("#cart .body"), 3);
    });

To submit a form, use `pressButton`.  The first argument can be a CSS
selector, the button/input element. the button name (the value of the
`name` argument) or the text that shows on the button.  You can press
any `BUTTON` element or `INPUT` of type `submit`, `reset` or `button`.
The second argument is a callback, just like `clickLink`.

Of course, before submitting a form, you'll need to fill it with values.
For text fields, use the `fill` function, which takes two arguments:
selector and the field value.  This time the selector can be a CSS
selector, the input element, the field name (its `name` attribute), or
the text that shows on the label associated with that field.

Zombie.js supports text fields, password fields, text areas, and also
the new HTML 5 fields types like email, search and url.

The `fill` function returns a reference to the browser, so you can chain
several functions together.  Its sibling functions `check` and `uncheck`
(for check boxes), `choose` (for radio buttons) and `select` (for drop
downs) work the same way.

Let's combine all of that into one example:

    // Fill in the form and submit.
    browser.
      fill("Your Name", "Arm Biter").
      fill("Profession", "Living dead").
      select("Born", "1968").
      uncheck("Send me the newsletter").
      pressButton("Sign me up", function(err, browser, status) {
        // Make sure we got redirected to thank you page.
        assert.equal(browser.location, "http://localhost:3003/thankyou");
      });

Read more [on the Browser API](api)


## Readiness

Zombie.js supports the following:

- HTML5 parsing and dealing with tag soups
- [DOM Level 3](http://www.w3.org/DOM/DOMTR) implementation
- HTML5 form fields (`search`, `url`, etc)
- CSS3 Selectors with [some extensions](http://sizzlejs.com/)
- Cookies and [Web Storage](http://dev.w3.org/html5/webstorage/)
- `XMLHttpRequest` in all its glory
- `setTimeout`/`setInterval` and messing with the system clock
- `pushState`, `popstate` and `hashchange` events
- Scripts that use `document.write`
- `alert`, `confirm` and `prompt`


## In The Family

**[capybara-zombie](https://github.com/plataformatec/capybara-zombie)** -- Capybara driver for zombie.js running on top of node.

**[zombie-jasmine-spike](https://github.com/mileskin/zombie-jasmine-spike)** -- Spike project for trying out Zombie.js with Jasmine


## Reporting Glitches

**Step 1:** Run Zombie with debugging turned on, the trace will help
figure out what it's doing. For example:

    var browser = new zombie.Browser({ debug: true });
    browser.visit("http://thedead", function(err, browser, status) {
      if (err)
        throw(err.message);
      ...
    });

**Step 2:** Wait for it to finish processing, then dump the current
browser state:

   brower.dump();

**Step 3:** If publicly available, include the URL of the page you're
trying to access.  Even better, provide a test script I can run from the
Node.js console (similar to step 1 above).

Read more [about troubleshooting](troubleshoot)


## Giving Back


* Find [assaf/zombie on Github](http://github.com/assaf/zombie)
* Fork the project
* Add tests
* Make your changes
* Send a pull request

Read more [about the guts of Zombie.js](guts) and check out the
outstanding [to-dos](todo).

Follow announcements, ask questions on [the Google
Group](https://groups.google.com/forum/?hl=en#!forum/zombie-js)

Get help on IRC: join [zombie.js on
Freenode](irc://irc.freenode.net/zombie.js) or [web-based
IRC](http://webchat.freenode.net/?channels=zombie-js)


## Brains

Zombie.js is copyright of [Assaf Arkin](http://labnotes.org), released
under the MIT License

Blood, sweat and tears of joy:

[Damian Janowski aka djanowski](https://github.com/djanowski)

[José Valim aka josevalim](http://blog.plataformatec.com.br/)

[Bob Lail boblail](http://boblail.tumblr.com/)

And all the fine people mentioned in [the changelog](changelog).

Zombie.js is written in
[CoffeeScript](http://jashkenas.github.com/coffee-script/) for
[Node.js](http://nodejs.org/)

DOM emulation by Elijah Insua's [JSDOM](http://jsdom.org/)

HTML5 parsing by Aria Stewart's [HTML5](https://github.com/aredridel/html5)

CSS selectors by John Resig's [Sizzle.js](http://sizzlejs.com/)

XPath support using Google's [AJAXSLT](http://code.google.com/p/ajaxslt/)

Magical Zombie Girl by [Toho Scope](http://www.flickr.com/people/tohoscope/)


## See Also

**zombie-api**(7), **zombie-troubleshoot**(7), **zombie-selectors**(7), **zombie-changelog**(7), **zombie-todo**(7)
