zombie.js troubleshoot(1) -- Troubleshooting
============================================


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


## Debugging

When running in debug mode, Zombie.js will spit out messages to the
console.  These could help you see what's going on as your tests
execute, especially useful around stuff that happens in the background,
like XHR requests.

To turn debugging on/off call `browser.debug` with a boolean.  You can
also call it with a boolean and a function, it will change the debug
status, call the function, and then revent the debug status to its
previous setting.

For example:

    browser.debug(true);
    // Everything that follows shows debug statements
    browser.debug(false, function() {
      // Except here, where debug is turned off
      ...
    });

If you're working on the code and you want to add more debug statements,
call `browser.debug` with any sequence of arguments (same as
`console.log`), or with a function.  In the later case, it will call the
function only when debugging is turned on, and spit the value returned
from the console.

For example:

    browser.debug("Currently visiting", browser.location);
    browser.debug(function() {
      return "Currently visiting " + browser.location;
    });

To figure out if debugging is on, call `browser.debug` with no
arguments.


## Request/response

The browser keeps a trail of every request, response or error.  You can
dump the last request/response to the console:

    // Last requet we made, including method, URL, headers
    console.log(browser.lastRequest);
    // Last response we received, inclusing status, body, headers
    console.log(browser.lastResponse);
    // Last error we received in lieu of a response
    console.log(browser.lastError);

