require "./jsdom_patches"
require "./forms"
require "./xpath"


{ deprecated }    = require("./helpers")
Cache             = require("./cache")
Cookies           = require("./cookies")
{ EventEmitter }  = require("events")
EventLoop         = require("./eventloop")
{ format }        = require("util")
FS                = require("fs")
{ HTML5 }         = require("html5")
Interact          = require("./interact")
JSDOM             = require("jsdom")
Mime              = require("mime")
Q                 = require("q")
Path              = require("path")
Resources         = require("./resources")
Storages          = require("./storage")
URL               = require("url")
Windows           = require("./windows")
XHR               = require("./xhr")


# Browser options you can set when creating new browser, or on browser instance.
BROWSER_OPTIONS = ["debug", "headers", "htmlParser", "loadCSS", "maxWait", "proxy",
                   "referer", "runScripts", "silent", "site", "userAgent",
                   "waitFor", "name", "maxRedirects"]

# Global options you can set on Browser and will be inherited by each new browser.
GLOBAL_OPTIONS  = ["debug", "headers", "htmlParser", "loadCSS", "maxWait", "proxy",
                   "runScripts", "silent", "site", "userAgent", "waitFor", "maxRedirects"]


PACKAGE = JSON.parse(require("fs").readFileSync(__dirname + "/../../package.json"))
VERSION = PACKAGE.version
HTML = JSDOM.dom.level3.html
MOUSE_EVENT_NAMES = ["mousedown", "mousemove", "mouseup"]


# Use the browser to open up new windows and load documents.
#
# The browser maintains state for cookies and local storage.
class Browser extends EventEmitter
  constructor: (options = {}) ->
    @cache = new Cache()
    @_cookies = new Cookies()
    @_storages = new Storages()
    @_interact = Interact.use(this)
    @_xhr = XHR.use()

    # Make sure we don't blow up Node when we get a JS error, but dump error to console.  Also, catch any errors
    # reported while processing resources/JavaScript.
    @on "error", (error)=>
      @errors.push error
      @log error.message, error.stack


    # Window becomes inactive
    @on "active", (window)=>
      onfocus = window.document.createEvent("HTMLEvents")
      onfocus.initEvent("focus", false, false)
      window.dispatchEvent(onfocus)
      if window.document.activeElement
        onfocus = window.document.createEvent("HTMLEvents")
        onfocus.initEvent("focus", false, false)
        window.document.activeElement.dispatchEvent(onfocus)

    # Window becomes inactive
    @on "inactive", (window)->
      if window.document.activeElement
        onblur = window.document.createEvent("HTMLEvents")
        onblur.initEvent("blur", false, false)
        window.document.activeElement.dispatchEvent(onblur)
      onblur = window.document.createEvent("HTMLEvents")
      onblur.initEvent("blur", false, false)
      window.dispatchEvent(onblur)

    # Window has been closed
    @on "closed", (window)->


    # Default (not global) options

    # Send this referer.
    @referer = undefined

    # You can set the browser window.name property
    @name = "nodejs"

    # Sets the browser options.
    for name in BROWSER_OPTIONS
      if options.hasOwnProperty(name)
        @[name] = options[name]
      else if ~GLOBAL_OPTIONS.indexOf(name)
        @[name] = Browser[name]

    @_setCredentials(options.credentials || Browser.credentials)

    # Returns all errors reported while loading this window.
    @errors = []

    @resources = new Resources(this)
    @windows = new Windows(this)


  # Global options
  # -------

  # True to have Zombie report what it's doing.
  @debug: false

  # Which parser to use (HTML5 by default). For example:
  #   Browser.htmlParser = require("html5").HTML5 // HTML5, forgiving
  #   Browser.htmlParser = require("htmlparser")  // Faster, stricter
  @htmlParser: HTML5

  # True to load external stylesheets.
  @loadCSS: true

  # Maximum time to wait (visit, wait, etc).
  @maxWait: "5s"
  
  # Proxy URL.
  #
  # Example
  #   Browser.proxy = "http://myproxy:8080"
  #   browser.visit("site", function(error, browser) {
  #   })
  @proxy: null

  # Run scripts included in or loaded from the page. Defaults to true.
  @runScripts: true

  # If true, supress `console.log` output from scripts.
  @silent: false

  # User agent string sent to server.
  @userAgent: "Mozilla/5.0 Chrome/10.0.613.0 Safari/534.15 Zombie.js/#{VERSION}"

  # You can use visit with a path, and it will make a request relative to this host/URL.
  @site: undefined

  # Tells `wait` and any function that uses `wait` how long to wait for, executing timers.  Defaults to 0.5 seconds.
  @waitFor: "0.5s"
  
  # Tells the browser how many redirects to follow before aborting a request. Defaults to 5
  @maxRedirects: 5

  # Additional headers to be sent with each HTTP request
  @headers: {}

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
      @_setCredentials(options.credentials)
      return =>
        @[k] = v for k,v of restore
    else
      return ->

  # Return a new browser with a snapshot of this browser's state.
  # Any changes to the forked browser's state do not affect this browser.
  fork: ->
    forked = new Browser()
    forked.loadCookies @saveCookies()
    forked.loadStorage @saveStorage()
    forked.loadHistory @saveHistory()
    forked.location = @location
    for name in BROWSER_OPTIONS
        forked[name] = @[name]
    return forked


  # Windows
  # -------

  # Returns the currently open window
  @prototype.__defineGetter__ "window", ->
    return @windows.current

  # Open new browser window.  Options are undocumented, use at your own peril.
  open: (options)->
    @window._eventloop.reset()
    @errors = []
    @resources.clear()
    return @windows.open(options || {})

  # ### browser.error => Error
  #
  # Returns the last error reported while loading this window.
  @prototype.__defineGetter__ "error", ->
    return @errors[@errors.length - 1]
  

  # Events
  # ------

  # Waits for the browser to complete loading resources and processing JavaScript events.
  #
  # You can pass a callback as the last argument.  Without a callback, this method returns a promise.
  #
  # With `duration` as the first argument, this method waits for the specified time (in milliseconds) and any
  # resource/JavaScript to complete processing.  Duration can also be a function, called after each event to determine
  # whether or not to proceed.
  #
  # Without duration, Zombie makes best judgement by waiting up to 5 seconds for the page to load resources (scripts,
  # XHR requests, iframes), process DOM events, and fire timeouts events.
  wait: (duration, callback)->
    if arguments.length < 2 && typeof duration == "function"
      [callback, duration] = [duration, null]
 
    deferred = Q.defer()
    if callback
      deferred.promise.then(callback, callback)
    last = @errors[@errors.length - 1]

    @window._eventloop.wait @window, duration, (error)=>
      newest = @errors[@errors.length - 1]
      unless error || last == newest
        error = newest
      if error
        deferred.reject(error)
      else
        deferred.resolve()
    return deferred.promise unless callback

  # Fire a DOM event.  You can use this to simulate a DOM event, e.g. clicking a link.  These events will bubble up and
  # can be cancelled.  Like `wait` this method either takes a callback or returns a promise.
  #
  # name - Even name (e.g `click`)
  # target - Target element (e.g a link)
  # callback - Wait for events to be processed, then call me (optional)
  fire: (name, target, callback)->
    type = if name in MOUSE_EVENT_NAMES then "MouseEvents" else "HTMLEvents"
    event = @document.createEvent(type)
    event.initEvent name, true, true
    @dispatchEvent target, event
    return @wait(callback)

  # Dispatch asynchronously.  Returns true if preventDefault was set.
  dispatchEvent: (target, event)->
    return @window._eventloop.dispatch(target, event)


  # Accessors
  # ---------

  # ### browser.queryAll(selector, context?) => Array
  #
  # Evaluates the CSS selector against the document (or context node) and return array of nodes.
  # (Unlike `document.querySelectorAll` that returns a node list).
  queryAll: (selector, context)->
    if selector
      context ||= @document
      ret = context.querySelectorAll(selector)
      return Array.prototype.slice.call(ret, 0)
    else
      context ||= @document.documentElement
      return [context]

  # ### browser.query(selector, context?) => Element
  #
  # Evaluates the CSS selector against the document (or context node) and return an element.
  query: (selector, context)->
    context ||= @document
    if selector
      context.querySelector(selector)
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
      return @queryAll(selector, context).map((e)-> e.textContent).join("").trim().replace(/\s+/g, " ")
    return @source

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
      return @queryAll(selector, context).map((e)-> e.outerHTML.trim()).join("")
    return @source

  # **Deprecated** please use `queryAll` instead.
  css: (selector, context)->
    deprecated "Browser.css is deprecated, please use browser.query and browser.queryAll instead."
    return @queryAll(selector, context)

  # ### browser.xpath(expression, context?) => XPathResult
  #
  # Evaluates the XPath expression against the document (or context node) and return the XPath result.  Shortcut for
  # `document.evaluate`.
  xpath: (expression, context)->
    return @document.evaluate(expression, context || @document.documentElement)

  # ### browser.document => Document
  #
  # Returns the main window's document. Only valid after opening a document (see `browser.open`).
  @prototype.__defineGetter__ "document", ->
    return @window.document

  # ### browser.body => Element
  #
  # Returns the body Element of the current document.
  @prototype.__defineGetter__ "body", ->
    return @document.querySelector("body")

  # ### browser.statusCode => Number
  #
  # Returns the status code of the request for loading the window.
  @prototype.__defineGetter__ "statusCode", ->
    return @response?[0]

  # ### browser.success => Boolean
  #
  # True if the status code is 2xx.
  @prototype.__defineGetter__ "success", ->
    return @statusCode >= 200 && @statusCode < 300

  # ### browser.redirected => Boolean
  #
  # Returns true if the request for loading the window followed a redirect.
  @prototype.__defineGetter__ "redirected", ->
    return !!@resources.last?.response?.redirected

  # ### source => String
  #
  # Returns the unmodified source of the document loaded by the browser
  @prototype.__defineGetter__ "source", ->
    return @response?[2]

  # ### close
  #
  # Close all windows, dispose of all resources. You want to call this if you're running out of memory.
  close: (window)->
    if window
      @windows.close(window)
    else
      while @windows.current
        @windows.close()


  # Navigation
  # ----------

  # ### browser.visit(url, callback?)
  # ### browser.visit(url, options, callback)
  #
  # Loads document from the specified URL, processes events and calls the callback.  If the second argument are options,
  # uses these options for the duration of the request and resets the options afterwards.
  #
  # The callback is called with null, the browser, status code and array of resource/JavaScript errors.
  visit: (url, options, callback)->
    if typeof options == "function" && !callback
      [callback, options] = [options, null]
    if typeof options != "object"
      [duration, options] = [options, null]

    deferred = Q.defer()
    reset_options = @withOptions(options)
    if site = @site
      site = "http://#{site}" unless /^(https?:|file:)/i.test(site)
      url = URL.resolve(site, URL.parse(URL.format(url)))
    @window.history._assign url
    @wait duration, (error)=>
      reset_options()
      if error
        deferred.reject(error)
      else
        deferred.resolve()
      if callback
        callback error, this, @statusCode, @errors
    return deferred.promise unless callback


  # ### browser.load(html, callback)
  #
  # Loads the HTML, processes events and calls the callback.
  #
  # Without a callback, returns a promise.
  load: (html, callback)->
    try
      @errors = []
      @document.open()
      @document.write html
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
    return @window.location
  #
  # ### browser.location = url
  #
  # Changes document location, loads new document if necessary (same as setting `window.location`).
  @prototype.__defineSetter__ "location", (url)->
    @window.location = url

  # ### browser.link(selector) : Element
  #
  # Finds and returns a link by its text content or selector.
  link: (selector)->
    # If the link has already been queried, return itself
    if selector instanceof HTML.Element
      return selector
    if link = @querySelector(selector)
      return link if link.tagName == "A"
    for link in @querySelectorAll("body a")
      if link.textContent.trim() == selector
        return link
    return

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
    return @fire("click", link, callback)

  # Return the history object.
  @prototype.__defineGetter__ "history", ->
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

  # Legacy support, remove in the future.
  _setCredentials: (credentials)->
    return unless credentials
    deprecated "This credentials option is deprecated, please use browser.authenticate(host) instead."
    switch credentials.scheme.toLowerCase()
      when "basic"
        @authenticate().basic(credentials.user || credentials.username, credentials.password)
      when "bearer"
        @authenticate().bearer(credentials.token)
      when "oauth"
        @authenticate().oauth(credentials.token)


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
    # Try more specific selector first.
    if field = @querySelector(selector)
      return field if field.tagName == "INPUT" || field.tagName == "TEXTAREA" || field.tagName == "SELECT"
    # Use field name (case sensitive).
    if field = @querySelector(":input[name='#{selector}']")
      return field
    # Try finding field from label.
    for label in @querySelectorAll("label")
      if label.textContent.trim() == selector
        # Label can either reference field or enclose it
        if for_attr = label.getAttribute("for")
          return @document.getElementById(for_attr)
        else
          return label.querySelector(":input")
    return

  # ### browser.fill(selector, value, callback) => this
  #
  # Fill in a field: input field or text area.
  #
  # selector - CSS selector, field name or text of the field label
  # value - Field value
  #
  # Without callback, returns this.
  fill: (selector, value, callback)->
    field = @field(selector)
    unless field && (field.tagName == "TEXTAREA" || (field.tagName == "INPUT"))
      throw new Error("No INPUT matching '#{selector}'")
    if field.getAttribute("disabled")
      throw new Error("This INPUT field is disabled")
    if field.getAttribute("readonly")
      throw new Error("This INPUT field is readonly")
    field.focus()
    field.value = value
    @fire "change", field, callback
    return this

  _setCheckbox: (selector, value, callback)->
    field = @field(selector)
    unless field && field.tagName == "INPUT" && field.type == "checkbox"
      throw new Error("No checkbox INPUT matching '#{selector}'")
    if field.getAttribute("disabled")
      throw new Error("This INPUT field is disabled")
    if field.getAttribute("readonly")
      throw new Error("This INPUT field is readonly")
    if field.checked ^ value
      field.click()
    @wait callback if callback
    return this

  # ### browser.check(selector, callback) => this
  #
  # Checks a checkbox.
  #
  # selector - CSS selector, field name or text of the field label
  #
  # Without callback, returns this.
  check: (selector, callback)->
    return @_setCheckbox(selector, true, callback)

  # ### browser.uncheck(selector, callback) => this
  #
  # Unchecks a checkbox.
  #
  # selector - CSS selector, field name or text of the field label
  #
  # Without callback, returns this.
  uncheck: (selector, callback)->
    return @_setCheckbox(selector, false, callback)

  # ### browser.choose(selector, callback) => this
  #
  # Selects a radio box option.
  #
  # selector - CSS selector, field value or text of the field label
  #
  # Returns this.
  choose: (selector, callback)->
    field = @field(selector) || @field("input[type=radio][value=\"#{escape(selector)}\"]")
    unless field && field.tagName == "INPUT" && field.type == "radio"
      throw new Error("No radio INPUT matching '#{selector}'")
    field.click()
    @wait callback if callback
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

  # ### browser.select(selector, value, callback) => this
  #
  # Selects an option.
  #
  # selector - CSS selector, field name or text of the field label
  # value - Value (or label) or option to select
  #
  # Without callback, returns this.
  select: (selector, value, callback)->
    option = @_findOption(selector, value)
    return @selectOption(option, callback)

  # ### browser.selectOption(option, callback) => this
  #
  # Selects an option.
  #
  # option - option to select
  #
  # Without callback, returns this.
  selectOption: (option, callback)->
    if option && !option.getAttribute("selected")
      select = @xpath("./ancestor::select", option).value[0]
      option.setAttribute("selected", "selected")
      select.focus()
      @fire "change", select, callback
    else if callback
      process.nextTick ->
        callback null, false
    return this

  # ### browser.unselect(selector, value, callback) => this
  #
  # Unselects an option.
  #
  # selector - CSS selector, field name or text of the field label
  # value - Value (or label) or option to unselect
  #
  # Without callback, returns this.
  unselect: (selector, value, callback)->
    option = @_findOption(selector, value)
    return @unselectOption(option, callback)

  # ### browser.unselectOption(option, callback) => this
  #
  # Unselects an option.
  #
  # option - option to unselect
  #
  # Without callback, returns this.
  unselectOption: (option, callback)->
    if option && option.getAttribute("selected")
      select = @xpath("./ancestor::select", option).value[0]
      unless select.multiple
        throw new Error("Cannot unselect in single select")
      option.removeAttribute("selected")
      select.focus()
      @fire "change", select, callback
    else if callback
      process.nextTick ->
        callback null, false
    return this

  # ### browser.attach(selector, filename, callback) => this
  #
  # Attaches a file to the specified input field.  The second argument is the file name.
  #
  # Without callback, returns this.
  attach: (selector, filename, callback)->
    field = @field(selector)
    unless field && field.tagName == "INPUT" && field.type == "file"
      throw new Error("No file INPUT matching '#{selector}'")
    if filename
      stat = FS.statSync(filename)
      file = new (@window.File)()
      file.name = Path.basename(filename)
      file.type = Mime.lookup(filename)
      file.size = stat.size
      field.files ||= []
      field.files.push file
      field.value = filename
    field.focus()
    @fire "change", field, callback
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
    inputs = @querySelectorAll(":submit, :reset, :button")
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
    return @fire("click", button, callback)

  # ### browser.focused => element
  #
  # Returns the element in focus.
  focused: ->
    return @document._focused


  # Cookies and storage
  # -------------------

  # Returns all the cookies for this domain/path. Domain defaults to hostname of currently open page. Path defaults to
  # "/".
  cookies: (domain, path)->
    return @_cookies.access(domain || @location.hostname, path || @location.pathname)
  
  # Save cookies to a text string.  You can use this to load them back later on using `browser.loadCookies`.
  saveCookies: ->
    @_cookies.save()

  # Load cookies from a text string (e.g. previously created using `browser.saveCookies`.
  loadCookies: (serialized)->
    @_cookies.load serialized

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

  # ### browser.viewInBrowser(name?)
  #
  # Views the current document in a real Web browser.  Uses the default system browser on OS X, BSD and Linux.  Probably
  # errors on Windows.
  viewInBrowser: (browser)->
    require("./bcat").bcat @html()

  # ### browser.lastRequest => HTTPRequest
  #
  # Returns the last request sent by this browser. The object will have the properties url, method, headers, and body.
  @prototype.__defineGetter__ "lastRequest", ->
    return @resources.last?.request
  
  # ### browser.lastResponse => HTTPResponse
  #
  # Returns the last response received by this browser. The object will have the properties url, status, headers and
  # body. Long bodies may be truncated.
  @prototype.__defineGetter__ "lastResponse", ->
    return @resources.last?.response
  
  # ### browser.lastError => Object
  #
  # Returns the last error received by this browser in lieu of response.
  @prototype.__defineGetter__ "lastError", ->
    return @resources.last?.error

  # Zombie can spit out messages to help you figure out what's going on as your code executes.
  #
  # To spit a message to the console when running in debug mode, call this method with one or more values (same as
  # `console.log`).  You can also call it with a function that will be evaluated only when running in debug mode.
  #
  # For example:
  #     browser.log("Opening page:", url);
  #     browser.log(function() { return "Opening page: " + url });
  log: ->
    unless @debug
      return
    if typeof(arguments[0]) == "function"
      args = [arguments[0]()]
    else
      args = arguments
    process.stdout.write(format("Zombie:", args...))
    process.stdout.write("\n")

  # Dump information to the consolt: Zombie version, current URL, history, cookies, event loop, etc.  Useful for
  # debugging and submitting error reports.
  dump: ->
    indent = (lines)-> lines.map((l) -> "  #{l}\n").join("")
    process.stdout.write "Zombie: #{VERSION}\n\n"
    process.stdout.write "URL: #{@window.location.href}\n"
    process.stdout.write "History:\n#{indent @window.history.dump()}\n"
    process.stdout.write "Cookies:\n#{indent @_cookies.dump()}\n"
    process.stdout.write "Storage:\n#{indent @_storages.dump()}\n"
    process.stdout.write "Eventloop:\n#{indent @window._eventloop.dump()}\n"
    if @document
      html = @document.outerHTML
      html = html.slice(0, 497) + "..." if html.length > 497
      process.stdout.write "Document:\n#{indent html.split("\n")}\n"
    else
      process.stdout.write "No document\n" unless @document


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


Browser.VERSION = VERSION
module.exports = Browser
