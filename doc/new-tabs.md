# Tabs

Just like your favorite Web browser, Zombie manages multiple open windows as
tabs.  New browsers start without any open tabs.  As you visit the first page,
Zombie will open a tab for it.

All operations against the `browser` object operate on the currently active tab
(window) and most of the time you only need to interact with that one tab.  You
can access it directly via `browser.window`.

Web pages can open additional tabs using the `window.open` method, or whenever a
link or form specifies a target (e.g. `target=_blank` or `target=window-name`).
You can also open additional tabs by calling `browser.open`.  To close the
currently active tab, close the window itself.

You can access all open tabs from `browser.tabs`.  This property is an
associative array, you can access each tab by its index number, and iterate over
all open tabs using functions like `forEach` and `map`.

If a window was opened with a name, you can also access it by its name.  Since
names may conflict with reserved properties/methods, you may need to use
`browser.tabs.find`.

The value of a tab is the currently active window.  That window changes when you
navigate forwards and backwards in history.  For example, if you visited the URL
"/foo" and then the URL "/bar", the first tab (`browser.tabs[0]`) would be a
window with the document from "/bar".  If you then navigate back in history, the
first tab would be the window with the document "/foo".

The following operations are used for managing tabs:

`browser.close(window)`

Closes the tab with the given window.

`browser.close()`

Closes the currently open tab.

`browser.tabs`

Returns an array of all open tabs.

`browser.tabs[number]`

Returns the tab with that index number.

`browser.tabs[string]`
`browser.tabs.find(string)`

Returns the tab with that name.

`browser.tabs.closeAll()`

Closes all tabs.

`browser.tabs.current`

Returns the currently active tab.

`browser.tabs.current = window`

Changes the currently active tab.  You can set it to a window (e.g. as currently
returned from `browser.current`), a window name or the tab index number.

`browser.tabs.dump(output)`

Dump a list of all open tabs to standard output, or the output stream.

`browser.tabs.index`

Returns the index of the currently active tab.

`browser.tabs.length`

Returns the number of currently opened tabs.

`browser.open(url: "http://example.com")`

Opens and returns a new tab.  Supported options are:
- `name` - Window name.
- `url` - Load document from this URL.

`browser.window`

Returns the currently active window, same as `browser.tabs.current.`
