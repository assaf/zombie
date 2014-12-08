# How to contribute

Follow these six steps:

* Fork the project
* Write your tests
* Make your changes
* Get the tests to pass
* Update the documentation, if necessary
* Push to your fork and send a pull request

Documentation changes and refactoring require no new tests.  Anything else, if
it's not covered by a test case, may fail in the future when the code changes
and there's no test spot the change.  If you care enough to see this feature or
bug fix in production, you should care enough to help us keep it around by
writing proper test cases.

Some of the things that will increase the chance of your issue getting resolved,
or your pull request getting accepted:

* Write tests that fail
* Explain the design of your solution
* Make it work for everyone, not just one special use case
* Optimize for code clarity, not cleverness or poetry
* Follow coding conventions

If in doubt, bring it up for discussion in the [Google
Group](https://groups.google.com/forum/?hl=en#!forum/zombie-js).


## Coding Convention

Our coding style may not be your preferred style, but it's what we got, and
consistency counts.  A lot.  So take a few minutes to familiarize yourself with
the code base.  With 10K+ lines of code, you're bound to find an example to
guide you in anything you need to write.

Specifically:

* We prefer explicit and verbose over crypted and terse
* We shy away from clever code
* We're opinionated and use two spaces for indentation
* We understand that parentheses are optional in CoffeeScript, but are required to
  read and understand the code
* If it looks like Perl or SQL, it's wrong


## Documentation

The documentation is written in [Github-flavored
Markdown](https://github.com/vmg/sundown).

The easiest way to review the documentation is by running the included server.
It lets you refresh the browser to see your recent changes.

```sh
$ ./scripts/live &
$ open http://localhost:3000
```

The documentation are also formatted to PDF and Mobi (Kindle).  You can generate
these files yourself (requires `wkhtmltopdf` and `kindlegen`):

```sh
$ ./scripts/docs
$ open html/index.html
$ open html/zombie.pdf
$ open html/zombie.html
```
