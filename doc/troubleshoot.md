zombie.js-troubleshoot(7) -- Troubleshooting guide
==================================================


## The Dump

Get the browser to dump its current state.  You'll be able to see the
current document URL, history, cookies, local/session storage, and
portion of the current page:

    browser.dump()

    URL: http://localhost:3003/here/#there

    History:
      1. http://localhost:3003/here
      2: http://localhost:3003/here/#there

    Cookies:
      session=e62ab205; domain=localhost; path=/here

    Storage:
      localhost:3003 session:
        day = Monday

    Document:
      <html>
        <head>
          <script src="/jquery.js"></script>
          <script src="/sammy.js"></script>
          <script src="/app.js"></script>
      </head>
        <body>
        ...

The actual report will have much more information.


## Debugging

When running in debug mode, Zombie.js will spit out messages to the
console.  These could help you see what's going on as your tests
execute, especially useful around stuff that happens in the background,
like XHR requests.

To turn debugging on/off set `browser.debug` to true/false.  You can
also set this option when creating a new `Browser` object (the
constructor takes an options argument), or for the duration of a single
call to `visit` (the second argument being the options).

For example:

    Browser.visit("http://thedead", { debug: true}, function(err, browser) {
      console.log(browser.errors);
      ... 
    });


If you're working on the code and you want to add more debug statements,
call `browser.log` with any sequence of arguments (same as
`console.log`), or with a function.  In the later case, it will call the
function only when debugging is turned on, and spit the value returned
from the console.

For example:

    browser.log("Currently visiting", browser.location);
    browser.log(function() {
      return "Currently visiting " + browser.location;
    });


## Request/response

Each window keeps a trail of every resource request it makes (to load
the page itself, scripts, XHR requests, etc).  You can inspect these by
obtaining the `window.resources` array and looking into it.

For example:

    browser.resources.dump()

The browser object provides the convenient methods `lastRequest`,
`lastResponse` and `lastError` that return, respectively, the request,
response and error associated with the last resources loaded by the
current window.
