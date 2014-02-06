assert            = require("assert")
Assert            = require("./assert")
createTabs        = require("./tabs")
Console           = require("./console")
Cookies           = require("./cookies")
{ EventEmitter }  = require("events")
EventLoop         = require("./eventloop")
{ format }        = require("util")
File              = require("fs")
HTML5             = require("html5")
Interact          = require("./interact")
HTML              = require("jsdom").dom.level3.html
Mime              = require("mime")
ms                = require("ms")
Q                 = require("q")
Path              = require("path")
Resources         = require("./resources")
Storages          = require("./storage")
Tough             = require("tough-cookie")
Cookie            = Tough.Cookie
URL               = require("url")
XPath             = require("jsdom").dom.level3.xpath


# DOM extensions.
require("./jsdom_patches")
require("./forms")
require("./dom_focus")
require("./dom_iframe")


# Browser options you can set when creating new browser, or on browser instance.
BROWSER_OPTIONS   = ["debug", "features", "headers", "htmlParser", "waitDuration",
                     "proxy", "referer", "silent", "site", "strictSSL", "userAgent",
                     "maxRedirects", "language", "runScripts"]

# Supported browser features.
BROWSER_FEATURES  = ["scripts", "css", "img", "iframe"]
# These features are set on/off by default.
DEFAULT_FEATURES  = "scripts no-css no-img iframe"

MOUSE_EVENT_NAMES = ["mousedown", "mousemove", "mouseup"]


# Use the browser to open up new windows and load documents.
#
# The browser maintains state for cookies and local storage.
class Browser extends EventEmitter
  constructor: (options = {}) ->
    browser = this
    @cookies = new Cookies()
    @_storages = new Storages()
    @_interact = Interact.use(this)
    # The window that is currently in scope, some JS functions need this, e.g.
    # when closing a window, you need to determine whether caller (window in
    # scope) is same as window.opener
    @_windowInScope = null

    # Used for assertions
    @assert = new Assert(this)


    # -- Console/Logging --

    # Shared by all windows.
    @console = new Console(this)

    # Message written to window.console.  Level is log, info, error, etc.
    #
    # Errors go to stderr, unless slient mode is on.
    # Debug go to stdout, if debug mode is on.
    # All other messages go to stdout, unless silent is on.
    @on "console", (level, message)->
      unless browser.silent
        switch level
          when "error"
            process.stderr.write(message + "\n")
          when "debug"
            if browser.debug
              process.stdout.write(message + "\n")
          else
            process.stdout.write(message + "\n")

    # Message written to browser.log.
    @on "log", (message)->
      if browser.debug
        process.stdout.write("Zombie: #{message}\n")


    # -- Resources --

    # Start with no this referer.
    @referer = null
    # All the resources loaded by this browser.
    @resources = new Resources(this)

    @on "request", (request)->

    @on "response", (request, response)->
      browser.log "#{request.method} #{request.url} => #{response.statusCode}"

    @on "redirect", (request, response)->
      browser.log "#{request.method} #{request.url} => #{response.statusCode} #{response.url}"

    # Document loaded.
    @on "loaded", (document)->
      browser.log "Loaded document", document.location.href


    # -- Tabs/Windows --

    # Open tabs.
    @tabs = createTabs(this)

    # Window has been opened
    @on "opened", (window)->
      browser.log "Opened window", window.location.href, window.name || ""

    # Window has been closed
    @on "closed", (window)->
      browser.log "Closed window", window.location.href, window.name || ""

    # Window becomes inactive
    @on "active", (window)->
      onfocus = window.document.createEvent("HTMLEvents")
      onfocus.initEvent("focus", false, false)
      window.dispatchEvent(onfocus)
      if element = window.document.activeElement
        onfocus = window.document.createEvent("HTMLEvents")
        onfocus.initEvent("focus", false, false)
        element.dispatchEvent(onfocus)

    # Window becomes inactive
    @on "inactive", (window)->
      if element = window.document.activeElement
        onblur = window.document.createEvent("HTMLEvents")
        onblur.initEvent("blur", false, false)
        element.dispatchEvent(onblur)
      onblur = window.document.createEvent("HTMLEvents")
      onblur.initEvent("blur", false, false)
      window.dispatchEvent(onblur)


    # -- Event loop --

    # The browser event loop.
    @eventLoop = new EventLoop(this)

    # Returns all errors reported while loading this window.
    @errors = []

    # Make sure we don't blow up Node when we get a JS error, but dump error to console.  Also, catch any errors
    # reported while processing resources/JavaScript.
    @on "error", (error)->
      browser.errors.push(error)
      browser.console.error(error.message, error.stack)

    @on "done", (timedOut)->
      if timedOut
        browser.log "Event loop timed out"
      else
        browser.log "Event loop is empty"

    @on "timeout", (fn, delay)->
      browser.log "Fired timeout after #{delay}ms delay"

    @on "interval", (fn, interval)->
      browser.log "Fired interval every #{interval}ms"

    @on "link", (url, target)->
      browser.log "Follow link to #{url}"

    @on "submit", (url, target)->
      browser.log "Submit form to #{url}"

    # Sets the browser options.
    for name in BROWSER_OPTIONS
      if options.hasOwnProperty(name)
        @[name] = options[name]
      else if Browser.default.hasOwnProperty(name)
        @[name] = Browser.default[name]

    # Last, run all extensions in order.
    for extension in Browser._extensions
      extension(this)


  # Register a browser extension.
  #
  # Browser extensions are called for each newly created browser object, and
  # can be used to change browser options, register listeners, add methods,
  # etc.
  @extend: (extension)->
    Browser._extensions.push(extension)

  @_extensions = []

  # Returns true if the given feature is enabled.
  #
  # If the feature is listed, then it is enabled.  If the feature is listed
  # with "no-" prefix, then it is disabled.  If the feature is missing, return
  # the default value.
  hasFeature: (name, ifMissing = true)->
    if @features
      features = @features.split(/\s+/)
      if ~features.indexOf(name)
        return true
      if ~features.indexOf("no-#{name}")
        return false
    return ifMissing


  # Changes the browser options, and calls the function with a callback (reset).  When you're done processing, call the
  # reset function to bring options back to their previous values.
  #
  # See `visit` if you want to see this method in action.
  withOptions: (options, fn)->
    if options
      restore = {}
      for k,v of options
        if ~BROWSER_OPTIONS.indexOf(k)
          [restore[k], @[k]] = [@[k], v]
      return =>
        @[k] = v for k,v of restore
    else
      return ->

  # Return a new browser with a snapshot of this browser's state.
  # Any changes to the forked browser's state do not affect this browser.
  fork: ->
    opt = {}
    for name in BROWSER_OPTIONS
        opt[name] = @[name]
    forked = Browser.create(opt)
    forked.loadCookies @saveCookies()
    forked.loadStorage @saveStorage()
    # forked.loadHistory @saveHistory()
    forked.location = @location.href
    return forked


  # Windows
  # -------

  # Returns the currently open window
  @prototype.__defineGetter__ "window", ->
    return @tabs.current

  # Open new browser window.
  open: (options)->
    if options
      { url, name, referer } = options
    return @tabs.open(url: url, name: name, referer: referer)

  # ### browser.error => Error
  #
  # Returns the last error reported while loading this window.
  @prototype.__defineGetter__ "error", ->
    return @errors[@errors.length - 1]


  # Events
  # ------

  # Waits for the browser to complete loading resources and processing JavaScript events.
  #
  # Accepts two parameters, both optional:
  # options   - Options that determine how long to wait (see below)
  # callback  - Called with error or null and browser
  #
  # To determine how long to wait:
  # duration  - Do not wait more than this duration (milliseconds or string of
  #             the form "5s"). Defaults to "5s" (see Browser.waitDuration).
  # element   - Stop when this element(s) appear in the DOM.
  # function  - Stop when function returns true; this function is called with
  #             the active window and expected time to the next event (0 to
  #             Infinity).
  #
  # As a convenience you can also pass the duration directly.
  #
  # Without a callback, this method returns a promise.
  wait: (options, callback)->
    unless @window
      process.nextTick ->
        callback new Error("No window open")
      return

    if arguments.length == 1 && typeof(options) == "function"
      [callback, options] = [options, null]

    if callback && typeof(callback) != "function"
      throw new Error("Second argument expected to be a callback function or null")
    # Support all sort of shortcuts for options. Unofficial.
    if typeof(options) == "number"
      waitDuration = options
    else if typeof(options) == "string"
      waitDuration = options
    else if typeof(options) == "function"
      waitDuration = @waitDuration
      completionFunction = options
    else if options
      waitDuration = options.duration || @waitDuration
      if options.element
        completionFunction = (window)->
          return !!window.document.querySelector(options.element)
      else
        completionFunction = options.function
    else
      waitDuration = @waitDuration

    promise = @eventLoop.wait(waitDuration, completionFunction)

    if callback
      promise.done(callback, callback)
    return promise


  # Fire a DOM event.  You can use this to simulate a DOM event, e.g. clicking
  # a link.  These events will bubble up and can be cancelled.  Like `wait`
  # this method takes an optional callback and returns a promise.
  #
  # name - Even name (e.g `click`)
  # target - Target element (e.g a link)
  # callback - Called with error or nothing
  #
  # Returns a promise
  fire: (selector, eventName, callback)->
    unless @window
      throw new Error("No window open")
    target = @query(selector)
    unless target && target.dispatchEvent
      throw new Error("No target element (note: call with selector/element, event name and callback)")
    if ~MOUSE_EVENT_NAMES.indexOf(eventName)
      eventType = "MouseEvents"
    else
      eventType = "HTMLEvents"
    event = @document.createEvent(eventType)
    event.initEvent(eventName, true, true)
    target.dispatchEvent(event)
    return @wait(callback)

  # Click on the element and returns a promise.
  #
  # selector - Element or CSS selector
  # callback - Called with error or nothing
  #
  # Returns a promise.
  click: (selector, callback)->
    return @fire(selector, "click", callback)

  # Dispatch asynchronously.  Returns true if preventDefault was set.
  dispatchEvent: (selector, event)->
    target = @query(selector)
    unless @window
      throw new Error("No window open")
    return target.dispatchEvent(event)


  # Accessors
  # ---------

  # ### browser.queryAll(selector, context?) => Array
  #
  # Evaluates the CSS selector against the document (or context node) and return array of nodes.
  # (Unlike `document.querySelectorAll` that returns a node list).
  queryAll: (selector, context)->
    if Array.isArray(selector)
      return selector
    else if selector instanceof HTML.Element
      return [selector]
    else if selector
      context ||= @document
      elements = context.querySelectorAll(selector)
      return Array.prototype.slice.call(elements, 0)
    else
      return []

  # ### browser.query(selector, context?) => Element
  #
  # Evaluates the CSS selector against the document (or context node) and return an element.
  query: (selector, context)->
    if selector instanceof HTML.Element
      return selector
    if selector
      context ||= @document
      return context.querySelector(selector)
    else
      return context

  # WebKit offers this.
  $$: (selector, context)->
    return @query(selector, context)

  # ### browser.querySelector(selector) => Element
  #
  # Select a single element (first match) and return it.
  #
  # selector - CSS selector
  #
  # Returns an Element or null
  querySelector: (selector)->
    return @document.querySelector(selector)

  # ### browser.querySelectorAll(selector) => NodeList
  #
  # Select multiple elements and return a static node list.
  #
  # selector - CSS selector
  #
  # Returns a NodeList or null
  querySelectorAll: (selector)->
    return @document.querySelectorAll(selector)

  # ### browser.text(selector, context?) => String
  #
  # Returns the text contents of the selected elements.
  #
  # selector - CSS selector (if missing, entire document)
  # context - Context element (if missing, uses document)
  #
  # Returns a string
  text: (selector, context)->
    if @document.documentElement
      return @queryAll(selector || "html", context)
        .map((e)-> e.textContent)
        .join("").trim().replace(/\s+/g, " ")
    else if @source
      return @source.toString()
    else
      return ""


  # ### browser.html(selector?, context?) => String
  #
  # Returns the HTML contents of the selected elements.
  #
  # selector - CSS selector (if missing, entire document)
  # context - Context element (if missing, uses document)
  #
  # Returns a string
  html: (selector, context)->
    if @document.documentElement
      return @queryAll(selector || "html", context)
        .map((e)-> e.outerHTML.trim())
        .join("")
    else if @source
      return @source.toString()
    else
      return ""

  # ### browser.xpath(expression, context?) => XPathResult
  #
  # Evaluates the XPath expression against the document (or context node) and return the XPath result.  Shortcut for
  # `document.evaluate`.
  xpath: (expression, context)->
    return @document.evaluate(expression, context || @document.documentElement, null, XPath.XPathResult.ANY_TYPE)

  # ### browser.document => Document
  #
  # Returns the main window's document. Only valid after opening a document (see `browser.open`).
  @prototype.__defineGetter__ "document", ->
    if @window
      return @window.document

  # ### browser.body => Element
  #
  # Returns the body Element of the current document.
  @prototype.__defineGetter__ "body", ->
    return @document.querySelector("body")

  # Element that has the current focus.
  @prototype.__defineGetter__ "activeElement", ->
    return @document.activeElement


  # Close the currently open tab, or the tab opened to the specified window.
  close: (window)->
    @tabs.close.apply(@tabs, arguments)

  # ### done
  #
  # Close all windows, clean state. You're going to need to call this to free up memory.
  destroy: ->
    if @tabs
      @tabs.closeAll()
      @tabs = null


  # Navigation
  # ----------

  # ### browser.visit(url, callback?)
  # ### browser.visit(url, options, callback)
  #
  # Loads document from the specified URL, processes events and calls the callback.  If the second argument are options,
  # uses these options for the duration of the request and resets the options afterwards.
  #
  # The callback is called with error, the browser and status code.
  visit: (url, options, callback)->
    if typeof options == "function" && !callback
      [callback, options] = [options, null]

    resetOptions = @withOptions(options)
    if site = @site
      site = "http://#{site}" unless /^(https?:|file:)/i.test(site)
      url = URL.resolve(site, URL.parse(URL.format(url)))

    if @window
      @tabs.close(@window)
    @tabs.open(url: url, referer: @referer)

    promise = @wait(options)
    promise.finally(resetOptions)
    if callback
      promise.done(callback, callback)
    return promise


  # ### browser.load(html, callback)
  #
  # Loads the HTML, processes events and calls the callback.
  #
  # Without a callback, returns a promise.
  load: (html, callback)->
    @location = "about:blank"
    try
      @errors = []
      @document.readyState = "loading"
      @document.open()
      @document.write(html)
      @document.close()
    catch error
      @emit "error", error

    # Find (first of any) errors caught during document.write
    first = @errors[0]
    if first
      # Call callback or resolve promise
      if callback
        process.nextTick ->
          callback(first)
        return
      else
        deferred = Q.defer()
        deferred.reject(first)
        return deferred.promise
    else
      # Otherwise wait for all events to process, wait handles errors
      return @wait(callback)


  # ### browser.location => Location
  #
  # Return the location of the current document (same as `window.location`).
  @prototype.__defineGetter__ "location", ->
    if @window
      return @window.location
  #
  # ### browser.location = url
  #
  # Changes document location, loads new document if necessary (same as setting `window.location`).
  @prototype.__defineSetter__ "location", (url)->
    if @window
      @window.location = url
    else
      this.open(url: url)

  # ### browser.url => String
  #
  # Return the URL of the current document (same as `document.URL`).
  @prototype.__defineGetter__ "url", ->
    if @window
      return URL.format(@window.location)

  # ### browser.link(selector) : Element
  #
  # Finds and returns a link by its text content or selector.
  link: (selector)->
    # If the link has already been queried, return itself
    if selector instanceof HTML.Element
      return selector
    link = @querySelector(selector)
    if link && link.tagName == "A"
      return link
    for link in @querySelectorAll("body a")
      if link.textContent.trim() == selector
        return link
    return null

  # ### browser.clickLink(selector, callback)
  #
  # Clicks on a link. Clicking on a link can trigger other events, load new page, etc: use a callback to be notified of
  # completion.  Finds link by text content or selector.
  #
  # selector - CSS selector or link text
  # callback - Called with two arguments: error and browser
  clickLink: (selector, callback)->
    unless link = @link(selector)
      throw new Error("No link matching '#{selector}'")
    return @click(link, callback)

  # Return the history object.
  @prototype.__defineGetter__ "history", ->
    unless @window
      this.open()
    return @window.history

  # Navigate back in history.
  back: (callback)->
    @window.history.back()
    return @wait(callback)

  # Reloads current page.
  reload: (callback)->
    @window.location.reload()
    return @wait(callback)

  # Returns a new Credentials object for the specified host.  These
  # authentication credentials will only apply when making requests to that
  # particular host (hostname:port).
  #
  # You can also set default credentials by using the host '*'.
  #
  # If you need to get the credentials without setting them, call with true as
  # the second argument.
  authenticate: (host, create = true)->
    host ||= "*"
    credentials = @_credentials?[host]
    unless credentials
      if create
        credentials = new Credentials()
        @_credentials ||= {}
        @_credentials[host] = credentials
      else
        credentials = @authenticate()
    return credentials


  # ### browser.saveHistory() => String
  #
  # Save history to a text string.  You can use this to load the data later on using `browser.loadHistory`.
  saveHistory: ->
    @window.history.save()

  # ### browser.loadHistory(String)
  #
  # Load history from a text string (e.g. previously created using `browser.saveHistory`.
  loadHistory: (serialized)->
    @window.history.load serialized


  # Forms
  # -----

  # ### browser.field(selector) : Element
  #
  # Find and return an input field (`INPUT`, `TEXTAREA` or `SELECT`) based on a CSS selector, field name (its `name`
  # attribute) or the text value of a label associated with that field (case sensitive, but ignores leading/trailing
  # spaces).
  field: (selector)->
    # If the field has already been queried, return itself
    if selector instanceof HTML.Element
      return selector
    try
      # Try more specific selector first.
      field = @query(selector)
      if field && (field.tagName == "INPUT" || field.tagName == "TEXTAREA" || field.tagName == "SELECT")
        return field
    catch error
      # Invalid selector, but may be valid field name

    # Use field name (case sensitive).
    for field in @queryAll("input[name],textarea[name],select[name]")
      if field.getAttribute("name") == selector
        return field

    # Try finding field from label.
    for label in @queryAll("label")
      if label.textContent.trim() == selector
        # Label can either reference field or enclose it
        if forAttr = label.getAttribute("for")
          return @document.getElementById(forAttr)
        else
          return label.querySelector("input,textarea,select")
    return


  # ### browser.focus(selector) : Element
  #
  # Turns focus to the selected input field.  Shortcut for calling `field(selector).focus()`.
  focus: (selector)->
    field = @field(selector) || @query(selector)
    unless field
      throw new Error("No form field matching '#{selector}'")
    field.focus()
    return this


  # ### browser.fill(selector, value) => this
  #
  # Fill in a field: input field or text area.
  #
  # selector - CSS selector, field name or text of the field label
  # value - Field value
  #
  # Returns this.
  fill: (selector, value)->
    field = @field(selector)
    unless field && (field.tagName == "TEXTAREA" || (field.tagName == "INPUT"))
      throw new Error("No INPUT matching '#{selector}'")
    if field.getAttribute("disabled")
      throw new Error("This INPUT field is disabled")
    if field.getAttribute("readonly")
      throw new Error("This INPUT field is readonly")

    # Switch focus to field, change value and emit the input event (HTML5)
    field.focus()
    field.value = value
    @fire(field, "input")
    # Switch focus out of field, if value changed, this will emit change event
    field.blur()
    return this

  _setCheckbox: (selector, value)->
    field = @field(selector)
    unless field && field.tagName == "INPUT" && field.type == "checkbox"
      throw new Error("No checkbox INPUT matching '#{selector}'")
    if field.getAttribute("disabled")
      throw new Error("This INPUT field is disabled")
    if field.getAttribute("readonly")
      throw new Error("This INPUT field is readonly")
    if field.checked ^ value
      field.click()
    return this

  # ### browser.check(selector) => this
  #
  # Checks a checkbox.
  #
  # selector - CSS selector, field name or text of the field label
  #
  # Returns this.
  check: (selector)->
    return @_setCheckbox(selector, true)

  # ### browser.uncheck(selector) => this
  #
  # Unchecks a checkbox.
  #
  # selector - CSS selector, field name or text of the field label
  #
  # Returns this.
  uncheck: (selector)->
    return @_setCheckbox(selector, false)

  # ### browser.choose(selector) => this
  #
  # Selects a radio box option.
  #
  # selector - CSS selector, field value or text of the field label
  #
  # Returns this.
  choose: (selector)->
    field = @field(selector) || @field("input[type=radio][value=\"#{escape(selector)}\"]")
    unless field && field.tagName == "INPUT" && field.type == "radio"
      throw new Error("No radio INPUT matching '#{selector}'")
    field.click()
    return this

  _findOption: (selector, value)->
    field = @field(selector)
    unless field && field.tagName == "SELECT"
      throw new Error("No SELECT matching '#{selector}'")
    if field.getAttribute("disabled")
      throw new Error("This SELECT field is disabled")
    if field.getAttribute("readonly")
      throw new Error("This SELECT field is readonly")
    for option in field.options
      if option.value == value
        return option
    for option in field.options
      if option.label == value
        return option
    for option in field.options
      if option.textContent.trim() == value
        return option
    throw new Error("No OPTION '#{value}'")

  # ### browser.select(selector, value) => this
  #
  # Selects an option.
  #
  # selector - CSS selector, field name or text of the field label
  # value - Value (or label) or option to select
  #
  # Returns this.
  select: (selector, value)->
    option = @_findOption(selector, value)
    @selectOption(option)
    return this

  # ### browser.selectOption(option) => this
  #
  # Selects an option.
  #
  # option - option to select
  #
  # Returns this.
  selectOption: (selector)->
    option = @query(selector)
    if option && !option.getAttribute("selected")
      select = @xpath("./ancestor::select", option).iterateNext()
      option.setAttribute("selected", "selected")
      select.focus()
      @fire(select, "change")
    return this

  # ### browser.unselect(selector, value) => this
  #
  # Unselects an option.
  #
  # selector - CSS selector, field name or text of the field label
  # value - Value (or label) or option to unselect
  #
  # Returns this.
  unselect: (selector, value)->
    option = @_findOption(selector, value)
    @unselectOption(option)
    return this

  # ### browser.unselectOption(option) => this
  #
  # Unselects an option.
  #
  # selector - selector or option to unselect
  #
  # Returns this.
  unselectOption: (selector)->
    option = @query(selector)
    if option && option.getAttribute("selected")
      select = @xpath("./ancestor::select", option).iterateNext()
      unless select.multiple
        throw new Error("Cannot unselect in single select")
      option.removeAttribute("selected")
      select.focus()
      @fire(select, "change")
    return this

  # ### browser.attach(selector, filename) => this
  #
  # Attaches a file to the specified input field.  The second argument is the file name.
  #
  # Returns this.
  attach: (selector, filename)->
    field = @field(selector)
    unless field && field.tagName == "INPUT" && field.type == "file"
      throw new Error("No file INPUT matching '#{selector}'")
    if filename
      stat = File.statSync(filename)
      file = new (@window.File)()
      file.name = Path.basename(filename)
      file.type = Mime.lookup(filename)
      file.size = stat.size
      field.files ||= []
      field.files.push file
      field.value = filename
    field.focus()
    @fire(field, "change")
    return this

  # ### browser.button(selector) : Element
  #
  # Finds a button using CSS selector, button name or button text (`BUTTON` or `INPUT` element).
  #
  # selector - CSS selector, button name or text of BUTTON element
  button: (selector)->
    # If the button has already been queried, return itself
    if selector instanceof HTML.Element
      return selector
    if button = @querySelector(selector)
      return button if button.tagName == "BUTTON" || button.tagName == "INPUT"
    for button in @querySelectorAll("button")
      return button if button.textContent.trim() == selector
    inputs = @querySelectorAll("input[type=submit],button")
    for input in inputs
      return input if input.name == selector
    for input in inputs
      return input if input.value == selector
    return

  # ### browser.pressButton(selector, callback)
  #
  # Press a button (button element or input of type `submit`).  Typically this will submit the form.  Use the callback
  # to wait for the from submission, page to load and all events run their course.
  #
  # selector - CSS selector, button name or text of BUTTON element
  # callback - Called with two arguments: null and browser
  pressButton: (selector, callback)->
    unless button = @button(selector)
      throw new Error("No BUTTON '#{selector}'")
    if button.getAttribute("disabled")
      throw new Error("This button is disabled")
    button.focus()
    @fire(button, "click")
    return @wait(callback)


  # -- Cookies --


  # Returns cookie that best matches the identifier.
  #
  # identifier - Identifies which cookie to return
  # allProperties - If true, return all cookie properties, other just the value
  #
  # Identifier is either the cookie name, in which case the cookie domain is
  # determined from the currently open Web page, and the cookie path is "/".
  #
  # Or the identifier can be an object specifying:
  # name   - The cookie name
  # domain - The cookie domain (defaults to hostname of currently open page)
  # path   - The cookie path (defaults to "/")
  #
  # Returns cookie value, or cookie object (see setCookie).
  getCookie: (identifier, allProperties)->
    identifier = @_cookieIdentifier(identifier)
    assert(identifier.name, "Missing cookie name")
    assert(identifier.domain, "No domain specified and no open page")
    cookie = @cookies.select(identifier)[0]
    if cookie
      if allProperties
        return @_cookieProperties(cookie)
      else
        return cookie.value
    else
      return null

  # Deletes cookie that best matches the identifier.
  #
  # identifier - Identifies which cookie to return
  #
  # Identifier is either the cookie name, in which case the cookie domain is
  # determined from the currently open Web page, and the cookie path is "/".
  #
  # Or the identifier can be an object specifying:
  # name   - The cookie name
  # domain - The cookie domain (defaults to hostname of currently open page)
  # path   - The cookie path (defaults to "/")
  #
  # Returns true if cookie delete.
  deleteCookie: (identifier)->
    identifier = @_cookieIdentifier(identifier)
    assert(identifier.name, "Missing cookie name")
    assert(identifier.domain, "No domain specified and no open page")
    cookie = @cookies.select(identifier)[0]
    if cookie
      @cookies.delete(cookie)
      return true
    else
      return false

  # Sets a cookie.
  #
  # You can call this function with two arguments to set a session cookie: the
  # cookie value and cookie name.  The domain is determined from the current
  # page URL, and the path is always "/".
  #
  # Or you can call it with a single argument, with all cookie options:
  # name     - Name of the cookie
  # value    - Value of the cookie
  # domain   - The cookie domain (e.g example.com, .example.com)
  # path     - The cookie path
  # expires  - Time when cookie expires
  # maxAge   - How long before cookie expires
  # secure   - True for HTTPS only cookie
  # httpOnly - True if cookie not accessible from JS
  setCookie: (nameOrOptions, value)->
    if location = @location
      domain = location.hostname
    if typeof(nameOrOptions) == "string"
      @cookies.set
        name:     nameOrOptions
        value:    value || ""
        domain:   domain
        path:     "/"
        secure:   false
        httpOnly: false
    else
      assert(nameOrOptions.name, "Missing cookie name")
      @cookies.set
        name:       nameOrOptions.name
        value:      nameOrOptions.value || value || ""
        domain:     nameOrOptions.domain || domain
        path:       nameOrOptions.path || "/"
        secure:     !!nameOrOptions.secure
        httpOnly:   !!nameOrOptions.httpOnly
        expires:    nameOrOptions.expires
        "max-age":  nameOrOptions["max-age"]
    return

  # Deletes all cookies.
  deleteCookies: ->
    @cookies.deleteAll()
    return

  # Save cookies to a text string.  You can use this to load them back
  # later on using `Browser.loadCookies`.
  saveCookies: ->
    serialized = ["# Saved on #{new Date().toISOString()}"]
    for cookie in @cookies.sort(Tough.cookieCompare)
      serialized.push cookie.toString()
    return serialized.join("\n") + "\n"

  # Load cookies from a text string (e.g. previously created using
  # `Browser.saveCookies`.
  loadCookies: (serialized)->
    for line in serialized.split(/\n+/)
      line = line.trim()
      continue if line[0] == "#" || line == ""
      @cookies.push(Cookie.parse(line))


  # Converts Tough Cookie object into Zombie cookie representation.
  _cookieProperties: (cookie)->
    properties =
      name:   cookie.key
      value:  cookie.value
      domain: cookie.domain
      path:   cookie.path
    if cookie.secure
      properties.secure = true
    if cookie.httpOnly
      properties.httpOnly = true
    if cookie.expires && cookie.expires < Infinity
      properties.expires = cookie.expires
    return properties

  # Converts cookie name/identifier into an identifier object.
  _cookieIdentifier: (identifier)->
    location = @location
    domain = location && location.hostname
    path   = location && location.pathname || "/"
    if typeof(identifier) == "string"
      identifier =
        name:   identifier
        domain: domain
        path:   path
    else
      identifier =
        name:   identifier.name
        domain: identifier.domain || domain
        path:   identifier.path || path
    return identifier


  # -- Local/Session Storage --


  # Returns local Storage based on the document origin (hostname/port). This is the same storage area you can access
  # from any document of that origin.
  localStorage: (host)->
    return @_storages.local(host)

  # Returns session Storage based on the document origin (hostname/port). This is the same storage area you can access
  # from any document of that origin.
  sessionStorage: (host)->
    return @_storages.session(host)

  # Save local/session storage to a text string.  You can use this to load the data later on using
  # `browser.loadStorage`.
  saveStorage: ->
    @_storages.save()

  # Load local/session stroage from a text string (e.g. previously created using `browser.saveStorage`.
  loadStorage: (serialized)->
    @_storages.load serialized


  # Scripts
  # -------

  # Evaluates a JavaScript expression in the context of the current window and returns the result.  When evaluating
  # external script, also include filename.
  #
  # You can also use this to evaluate a function in the context of the window: for timers and asynchronous callbacks
  # (e.g. XHR).
  evaluate: (code, filename)->
    unless @window
      this.open()
    return @window._evaluate code, filename


  # Interaction
  # -----------

  # ### browser.onalert(fn)
  #
  # Called by `window.alert` with the message.
  onalert: (fn)->
    @_interact.onalert fn

  # ### browser.onconfirm(question, response)
  # ### browser.onconfirm(fn)
  #
  # The first form specifies a canned response to return when `window.confirm` is called with that question.  The second
  # form will call the function with the question and use the respone of the first function to return a value (true or
  # false).
  #
  # The response to the question can be true or false, so all canned responses are converted to either value.  If no
  # response available, returns false.
  onconfirm: (question, response)->
    @_interact.onconfirm question, response

  # ### browser.onprompt(message, response)
  # ### browser.onprompt(fn)
  #
  # The first form specifies a canned response to return when `window.prompt` is called with that message.  The second
  # form will call the function with the message and default value and use the response of the first function to return
  # a value or false.
  #
  # The response to a prompt can be any value (converted to a string), false to indicate the user cancelled the prompt
  # (returning null), or nothing to have the prompt return the default value or an empty string.
  onprompt: (message, response)->
    @_interact.onprompt message, response

  # ### browser.prompted(message) => boolean
  #
  # Returns true if user was prompted with that message (`window.alert`, `window.confirm` or `window.prompt`)
  prompted: (message)->
    @_interact.prompted(message)


  # Debugging
  # ---------

  @prototype.__defineGetter__ "statusCode", ->
    if @window && @window._response
      return @window._response.statusCode
    else
      return null

  @prototype.__defineGetter__ "success", ->
    statusCode = @statusCode
    return statusCode >= 200 && statusCode < 400

  @prototype.__defineGetter__ "redirected", ->
    return @window && @window._response && @window._response.redirects > 0

  @prototype.__defineGetter__ "source", ->
    if @window && @window._response
      return @window._response.body
    else
      return null


  # ### browser.viewInBrowser(name?)
  #
  # Views the current document in a real Web browser.  Uses the default system browser on OS X, BSD and Linux.  Probably
  # errors on Windows.
  viewInBrowser: (browser)->
    require("./bcat").bcat @html()

  # Zombie can spit out messages to help you figure out what's going on as your code executes.
  #
  # To spit a message to the console when running in debug mode, call this method with one or more values (same as
  # `console.log`).  You can also call it with a function that will be evaluated only when running in debug mode.
  #
  # For example:
  #     browser.log("Opening page:", url);
  #     browser.log(function() { return "Opening page: " + url });
  log: ->
    if typeof(arguments[0]) == "function"
      args = [arguments[0]()]
    else
      args = arguments
    @emit "log", format(args...)

  # Dump information to the console: Zombie version, current URL, history, cookies, event loop, etc.  Useful for
  # debugging and submitting error reports.
  dump: ->
    indent = (lines)-> lines.map((l) -> "  #{l}\n").join("")
    process.stdout.write "Zombie: #{Browser.VERSION}\n\n"
    process.stdout.write "URL: #{@window.location.href}\n"
    process.stdout.write "History:\n#{indent @window.history.dump()}\n"
    process.stdout.write "Cookies:\n#{indent @cookies.dump()}\n"
    process.stdout.write "Storage:\n#{indent @_storages.dump()}\n"
    process.stdout.write "Eventloop:\n#{indent @eventLoop.dump()}\n"
    if @document
      html = @document.outerHTML
      html = html.slice(0, 497) + "..." if html.length > 497
      process.stdout.write "Document:\n#{indent html.split("\n")}\n"
    else
      process.stdout.write "No document\n" unless @document



# Version number.  We get this from package.json.
Browser.VERSION = JSON.parse(File.readFileSync("#{__dirname}/../../package.json")).version


# -- Global options --

# These defaults are used in any new browser instance.
Browser.default =
  # True to have Zombie report what it's doing.
  debug: false

  # Which features are enabled.
  features: DEFAULT_FEATURES

  # Which parser to use (HTML5 by default). For example:
  #   Browser.default.htmlParser = require("html5")       // HTML5, forgiving
  #   Browser.default.htmlParser = require("htmlparser2")  // Faster, stricter
  htmlParser: HTML5

  # Tells the browser how many redirects to follow before aborting a request. Defaults to 5
  maxRedirects: 5

  # Proxy URL.
  #
  # Example
  #   Browser.default.proxy = "http://myproxy:8080"
  proxy: null

  # If true, supress `console.log` output from scripts.
  silent: false

  # You can use visit with a path, and it will make a request relative to this host/URL.
  site: undefined

  # Check SSL certificates against CA.  False by default since you're likely
  # testing with a self-signed certificate.
  strictSSL: false

  # User agent string sent to server.
  userAgent: "Mozilla/5.0 Chrome/10.0.613.0 Safari/534.15 Zombie.js/#{Browser.VERSION}"

  # Navigator language code
  language: "en-US"

  # Default time to wait (visit, wait, etc).
  waitDuration: "5s"

  # Indicates whether or not to validate and execute JavaScript, default true.
  runScripts: true



# Use this function to create a new Browser instance.
Browser.create = (options)->
  return new Browser(options)


# Represents credentials for a given host.
class Credentials
  # Apply security credentials to the outgoing request headers.
  apply: (headers)->
    switch @scheme
      when "basic"
        base64 = new Buffer(@user + ":" + @password).toString("base64")
        headers["authorization"] = "Basic #{base64}"
      when "bearer"
        headers["authorization"] = "Bearer #{@token}"
      when "oauth"
        headers["authorization"] = "OAuth #{@token}"

  # Use HTTP Basic authentication.  Requires two arguments, username and password.
  basic: (@user, @password)->
    @scheme = "basic"

  # Use OAuth 2.0 Bearer (recent drafts).  Requires one argument, the access token.
  bearer: (@token)->
    @scheme = "bearer"

  # Use OAuth 2.0 (early drafts).  Requires one argument, the access token.
  oauth: (@token)->
    @scheme = "oauth"

  # Reset these credentials.
  reset: ->
    delete @scheme
    delete @token
    delete @user
    delete @password


module.exports = Browser
