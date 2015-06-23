# How to contribute

Please note that this project is released with a [Contributor Code of
Conduct](code_of_conduct.md). By participating in this project you agree to
abide by its terms.

## Bugs/fixes

If you are reporting a bug, or adding/changing a feature, providing a test case
will go a long way towards getting your change merged or issue fixed.

Unfortunately, if you just drop a code sample in the Github issue/Gist, that
doesn't provide us with a failing test.  Someone will have to write that test,
before working on the fix/change.

The process is standard fair:

1. Fork and clone
2. `npm install`
3. `npm test`
4. Write your test(s)
5. Any code changes you want to add
6. `git push`
7. Submit a pull request

If you're making a documentation change, Github allows you to edit `README.md`
directly from [the web
page](https://github.com/assaf/zombie/blob/master/README.md) and will handle
forking and pull request for you.


## Coding Convention

Zombie uses [ESLint](http://eslint.org) for linting and enforcing coding style.
It is written with ES7/2016, so we can use all the [fancy new ES6 language
features](https://babeljs.io/docs/learn-es6/)
and  `async/await`.

The project includes `.eslintrc` files and the ESLint/Babel.js dependencies.
You can [check here](http://eslint.org/docs/user-guide/integrations) to learn
how to use ESLint with just about any text editor.


## Documentation

The documentation is written in [Github-flavored
Markdown](https://github.com/vmg/sundown).

