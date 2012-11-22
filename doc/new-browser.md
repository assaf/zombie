

`browser.assert`

Methods for making assertions against the browser, such as
`browser.assert.element(".foo")`.

See *Assertions* section for detailed discussion.


`browser.console`

Provides access to the browser console (same as `window.console`).


`browser.referer`

You can use this to set the HTTP Referer header.


`browser.resources`

Access to history of retrieved resources.  Also provides methods for retrieving
resources and managing the resource pipeline.  When things are not going your
way, try calling `browser.resources.dump()`.

See *Resources* section for detailed discussion.


`browser.tabs`

Array of all open tabs (windows).  Allows you to operate on more than one open
window at a time.

See *Tabs* section for detailed discussion.


`browser.eventLoop`
`browser.errors`
