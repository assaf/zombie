jsdom = require("jsdom")
html = jsdom.dom.level3.html
vm = process.binding("evals")
require "./jsdom_patches"
require "./forms"
require "./xpath"



# Use the browser to open up new windows and load documents.
#
# The browser maintains state for cookies and localStorage.
class Browser extends require("events").EventEmitter
  constructor: (options) ->
    cache = require("./cache").use(this)
    cookies = require("./cookies").use(this)
    storage = require("./storage").use(this)
    eventloop = require("./eventloop").use(this)
    history = require("./history").use(this)
    interact = require("./interact").use(this)
    xhr = require("./xhr").use(cache)
    resources = require("./resources")


    # Options
    # -------

    @OPTIONS = ["debug", "runScripts", "userAgent"]

    # ### debug
    #
    # True to have Zombie report what it's doing.
    @debug = false
    # ### runScripts
    #
    # Run scripts included in or loaded from the page. Defaults to true.
    @runScripts = true
    # ### userAgent
    #
    # User agent string sent to server.
    @userAgent = "Mozilla/5.0 Chrome/10.0.613.0 Safari/534.15 Zombie.js/#{exports.version}"


    # ### withOptions(options, fn)
    #
    # Changes the browser options, and calls the function with a
    # callback (reset).  When you're done processing, call the reset
    # function to bring options back to their previous values.
    #
    # See `visit` if you want to see this method in action.
    @withOptions = (options, fn)->
      if options
        restore = {}
        [restore[k], @[k]] = [@[k], v] for k,v of options
      fn =>
        @[k] = v for k,v of restore if restore

    # Sets the browser options.
    if options
      for k,v of options
        if @OPTIONS.indexOf(k) >= 0
          @[k] = v
        else
          throw "I don't recognize the option #{k}"

    # Fork
    # ----

    # ### browser.fork() => Browser
    #
    # Return a new browser with a snapshot of this browser's data.
    # Any changes to the forked browser's state do not affect this browser.
    this.fork = ->
      forked = new Browser()
      forked.importCookies(cookies.dump())
      forked.importStorage(storage.dump())
      return forked
    this.importCookies = (serialized) ->
      cookies.from(serialized)
    this.importStorage = (serialized) ->
      storage.from(serialized)

    # Windows
    # -------

    window = null
    # ### browser.open() => Window
    #
    # Open new browser window.
    this.open = ->
      window = jsdom.createWindow(html)
      window.__defineGetter__ "browser", => this
      window.__defineGetter__ "title", => @window?.document?.title
      window.__defineSetter__ "title", (title)=> @window?.document?.title = title
      window.navigator.userAgent = @userAgent
      resources.extend window
      cookies.extend window
      storage.extend window
      eventloop.extend window
      history.extend window
      interact.extend window
      xhr.extend window
      window.screen = new Screen()
      window.JSON = JSON
      # Default onerror handler.
      window.onerror = (event)=> @emit "error", event.error || new Error("Error loading script")
      # TODO: Fix
      window.Image = ->
      return window



    # Events
    # ------

    # ### browser.wait(callback?)
    # ### browser.wait(terminator, callback)
    #
    # Process all events from the queue. This method returns immediately, events
    # are processed in the background. When all events are exhausted, it calls
    # the callback with `null, browser`; if any event fails, it calls the
    # callback with the exception.
    #
    # With one argument, that argument is the callback. With two arguments, the
    # first argument is a terminator and the last argument is the callback. The
    # terminator is one of:
    #
    # * null -- process all events
    # * number -- process that number of events
    # * function -- called after each event, stop processing when function
    #   returns false
    #
    # You can call this method with no arguments and simply listen to the `done`
    # and `error` events.
    #
    # Events include timeout, interval and XHR `onreadystatechange`. DOM events
    # are handled synchronously.
    this.wait = (terminate, callback)->
      if !callback
        [callback, terminate] = [terminate, null]
      if callback
        onerror = (error)=>
          @removeListener "error", onerror
          @removeListener "done", ondone
          callback error
        ondone = (error)=>
          @removeListener "error", onerror
          @removeListener "done", ondone
          callback null, this
        @on "error", onerror
        @on "done", ondone
      eventloop.wait window, terminate
      return

    # ### browser.fire(name, target, callback?)
    #
    # Fire a DOM event.  You can use this to simulate a DOM event, e.g. clicking a
    # link.  These events will bubble up and can be cancelled.  With a callback, this
    # method will call `wait`.
    #
    # * name -- Even name (e.g `click`)
    # * target -- Target element (e.g a link)
    # * callback -- Wait for events to be processed, then call me (optional)
    this.fire = (name, target, options, callback)->
      [callback, options] = [options, null] if typeof(options) == 'function'
      options ?= {}

      klass = options.klass || if (name in mouseEventNames) then "MouseEvents" else "HTMLEvents"
      bubbles = options.bubbles ? true
      cancelable = options.cancelable ? true

      event = window.document.createEvent(klass)
      event.initEvent(name, bubbles, cancelable)

      if options.attributes?
        for key, value of options.attributes
          event[key] = value

      target.dispatchEvent event

      @wait callback if callback

    mouseEventNames = ['mousedown', 'mousemove', 'mouseup']

    # ### browser.clock => Number
    #
    # The current system time according to the browser (see also
    # `browser.clock`).
    #
    # You can change this to advance the system clock during tests.  It will
    # also advance when handling timeout/interval events.
    @clock = new Date().getTime()
    # ### browser.now => Date
    #
    # The current system time according to the browser (see also
    # `browser.clock`).
    @__defineGetter__ "now", -> new Date(@clock)


    # Accessors
    # ---------

    # ### browser.querySelector(selector) => Element
    #
    # Select a single element (first match) and return it.
    #
    # * selector -- CSS selector
    #
    # Returns an Element or null
    this.querySelector = (selector)->
      window.document?.querySelector(selector)

    # ### browser.querySelectorAll(selector) => NodeList
    #
    # Select multiple elements and return a static node list.
    #
    # * selector -- CSS selector
    #
    # Returns a NodeList or null
    this.querySelectorAll = (selector)-> window.document?.querySelectorAll(selector)

    # ### browser.text(selector, context?) => String
    #
    # Returns the text contents of the selected elements.
    #
    # * selector -- CSS selector (if missing, entire document)
    # * context -- Context element (if missing, uses document)
    #
    # Returns a string
    this.text = (selector, context)->
      return "" unless @document.documentElement
      @css(selector, context).map((e)-> e.textContent).join("")

    # ### browser.html(selector?, context?) => String
    #
    # Returns the HTML contents of the selected elements.
    #
    # * selector -- CSS selector (if missing, entire document)
    # * context -- Context element (if missing, uses document)
    #
    # Returns a string
    this.html = (selector, context)->
      return "" unless @document.documentElement
      @css(selector, context).map((e)-> e.outerHTML.trim()).join("")

    # ### browser.css(selector, context?) => NodeList
    #
    # Evaluates the CSS selector against the document (or context node) and
    # return a node list.  Shortcut for `document.querySelectorAll`.
    this.css = (selector, context)->
      if selector then (context || @document).querySelectorAll(selector).toArray() else [@document]

    # ### browser.xpath(expression, context?) => XPathResult
    #
    # Evaluates the XPath expression against the document (or context node) and
    # return the XPath result.  Shortcut for `document.evaluate`.
    this.xpath = (expression, context)->
      @document.evaluate(expression, context || @document)


    # ### browser.window => Window
    #
    # Returns the main window.
    @__defineGetter__ "window", -> window
    # ### browser.document => Document
    #
    # Returns the main window's document. Only valid after opening a document
    # (see `browser.open`).
    @__defineGetter__ "document", -> window?.document
    # ### browser.body => Element
    #
    # Returns the body Element of the current document.
    @__defineGetter__ "body", -> window.document?.querySelector("body")


    # ### browser.statusCode => Number
    #
    # Returns the status code of the request for loading the window.
    @__defineGetter__ "statusCode", ->
      @window.resources.first?.response.statusCode
    # ### browser.redirected => Boolean
    #
    # Returns true if the request for loading the window followed a
    # redirect.
    @__defineGetter__ "redirected", ->
      @window.resources.first?.response.redirected
    # ### source => String
    #
    # Returns the unmodified source of the document loaded by the browser
    @__defineGetter__ "source", => @window.resources.first?.response.body

    # ### browser.cache => Cache
    #
    # Returns the browser's cache.
    @__defineGetter__ "cache", -> cache


    # Navigation
    # ----------

    # ### browser.visit(url, callback?)
    # ### browser.visit(url, options, callback)
    #
    # Loads document from the specified URL, processes events and calls the
    # callback.  If the second argument are options, uses these options
    # for the duration of the request and resets the options afterwards.
    #
    # If it fails to download, calls the callback with the error.
    this.visit = (url, options, callback)->
      if typeof options is "function"
        [callback, options] = [options, null]
      @withOptions options, (reset)=>
        history._assign url
        @wait (error, browser)->
          reset()
          if callback && error
            callback error
          else if callback
            callback null, browser, browser.statusCode
      return

    # ### browser.location => Location
    #
    # Return the location of the current document (same as `window.location`).
    @__defineGetter__ "location", -> window.location
    # ### browser.location = url
    #
    # Changes document location, loads new document if necessary (same as
    # setting `window.location`).
    @__defineSetter__ "location", (url)-> window.location = url

    # ### browser.link(selector) : Element
    #
    # Finds and returns a link by its text content or selector.
    this.link = (selector)->
      if link = @querySelector(selector)
        return link if link.tagName == "A"
      for link in @querySelectorAll("body a")
        if link.textContent.trim() == selector
          return link
      return

    # ### browser.clickLink(selector, callback)
    #
    # Clicks on a link. Clicking on a link can trigger other events, load new
    # page, etc: use a callback to be notified of completion.  Finds link by
    # text content or selector.
    #
    # * selector -- CSS selector or link text
    # * callback -- Called with two arguments: error and browser
    this.clickLink = (selector, callback)->
      if link = @link(selector)
        @fire "click", link, =>
          callback null, this, this.statusCode
      else
        callback new Error("No link matching '#{selector}'")


    # Forms
    # -----

    # ### browser.field(selector) : Element
    #
    # Find and return an input field (`INPUT`, `TEXTAREA` or `SELECT`) based on
    # a CSS selector, field name (its `name` attribute) or the text value of a
    # label associated with that field (case sensitive, but ignores
    # leading/trailing spaces).
    this.field = (selector)->
      # If the field has already been queried, return itself
      if selector instanceof html.Element
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

    # HTML5 field types that you can "fill in".
    TEXT_TYPES = "email number password range search text url".split(" ")

    # ### browser.fill(selector, value) => this
    #
    # Fill in a field: input field or text area.
    #
    # * selector -- CSS selector, field name or text of the field label
    # * value -- Field value
    #
    # Returns this
    this.fill = (selector, value)->
      field = @field(selector)
      if field && (field.tagName == "TEXTAREA" || (field.tagName == "INPUT")) # && TEXT_TYPES.indexOf(field.type) >= 0))
        throw new Error("This INPUT field is disabled") if field.getAttribute("input")
        throw new Error("This INPUT field is readonly") if field.getAttribute("readonly")
        field.value = value
        @fire "change", field
        return this
      throw new Error("No INPUT matching '#{selector}'")

    setCheckbox = (selector, value)=>
      field = @field(selector)
      if field && field.tagName == "INPUT" && field.type == "checkbox"
        throw new Error("This INPUT field is disabled") if field.getAttribute("input")
        throw new Error("This INPUT field is readonly") if field.getAttribute("readonly")
        if(field.checked ^ value)
          @fire "click", field
        return this
      else
        throw new Error("No checkbox INPUT matching '#{selector}'")

    # ### browser.check(selector) => this
    #
    # Checks a checkbox.
    #
    # * selector -- CSS selector, field name or text of the field label
    #
    # Returns this
    this.check = (selector)-> setCheckbox(selector, true)

    # ### browser.uncheck(selector) => this
    #
    # Unchecks a checkbox.
    #
    # * selector -- CSS selector, field name or text of the field label
    #
    # Returns this
    this.uncheck = (selector)-> setCheckbox(selector, false)

    # ### browser.choose(selector) => this
    #
    # Selects a radio box option.
    #
    # * selector -- CSS selector, field value or text of the field label
    #
    # Returns this
    this.choose = (selector)->
      field = @field(selector)
      if field.tagName == "INPUT" && field.type == "radio" && field.form
        if(!field.checked)
          radios = @querySelectorAll(":radio[name='#{field.getAttribute("name")}']", field.form)
          for radio in radios
            radio.checked = false unless radio.getAttribute("disabled") || radio.getAttribute("readonly")
          field.checked = true
          @fire "change", field

        @fire "click", field
        return this
      throw new Error("No radio INPUT matching '#{selector}'")

    findOption = (selector, value)=>
      field = @field(selector)
      if field && field.tagName == "SELECT"
        throw new Error("This SELECT field is disabled") if field.getAttribute("disabled")
        throw new Error("This SELECT field is readonly") if field.getAttribute("readonly")
        for option in field.options
          if option.value == value
            return option
        for option in field.options
          if option.label == value
            return option
        throw new Error("No OPTION '#{value}'")
      else
        throw new Error("No SELECT matching '#{selector}'")

    # ### browser.attach(selector, filename) => this
    #
    # Attaches a file to the specified input field.  The second argument is the
    # file name.
    this.attach = (selector, filename)->
      field = @field(selector)
      if field && field.tagName == "INPUT" && field.type == "file"
        field.value = filename
        @fire "change", field
        return this
      else
        throw new Error("No file INPUT matching '#{selector}'")

    # ### browser.select(selector, value) => this
    #
    # Selects an option.
    #
    # * selector -- CSS selector, field name or text of the field label
    # * value -- Value (or label) or option to select
    #
    # Returns this
    this.select = (selector, value)->
      option = findOption(selector, value)
      @selectOption(option)
      return this

    # ### browser.selectOption(option) => this
    #
    # Selects an option.
    #
    # * option -- option to select
    #
    # Returns this
    this.selectOption = (option)->
      if(option && !option.selected)
        select = @xpath("./ancestor::select", option).value[0]
        @fire "beforeactivate", select
        option.selected = true
        @fire "beforedeactivate", select
        @fire "change", select
      return this

    # ### browser.unselect(selector, value) => this
    #
    # Unselects an option.
    #
    # * selector -- CSS selector, field name or text of the field label
    # * value -- Value (or label) or option to unselect
    #
    # Returns this
    this.unselect = (selector, value)->
      option = findOption(selector, value)
      @unselectOption(option)
      return this

    # ### browser.unselectOption(option) => this
    #
    # Unselects an option.
    #
    # * option -- option to unselect
    #
    # Returns this
    this.unselectOption = (option)->
      if(option && option.selected)
        select = @xpath("./ancestor::select", option).value[0]
        throw new Error("Cannot unselect in single select") unless select.multiple
        option.removeAttribute('selected')
        @fire "change", select
      return this

    # ### browser.button(selector) : Element
    #
    # Finds a button using CSS selector, button name or button text (`BUTTON` or
    # `INPUT` element).
    #
    # * selector -- CSS selector, button name or text of BUTTON element
    this.button = (selector)->
      if button = @querySelector(selector)
        return button if button.tagName == "BUTTON" || button.tagName == "INPUT"
      for button in @querySelectorAll("form button")
        return button if button.textContent.trim() == selector
      inputs = @querySelectorAll("form :submit, form :reset, form :button")
      for input in inputs
        return input if input.name == selector
      for input in inputs
        return input if input.value == selector
      return

    # ### browser.pressButton(selector, callback)
    #
    # Press a button (button element or input of type `submit`).  Typically
    # this will submit the form.  Use the callback to wait for the from
    # submission, page to load and all events run their course.
    #
    # * selector -- CSS selector, button name or text of BUTTON element
    # * callback -- Called with two arguments: error and browser
    this.pressButton = (selector, callback)->
      if button = @button(selector)
        if button.getAttribute("disabled")
          callback new Error("This button is disabled")
        else
          @fire "click", button, =>
            callback null, this, this.statusCode
      else
        callback new Error("No BUTTON '#{selector}'")


    # Cookies and storage
    # -------------------

    # ### browser.cookies(domain, path) => Cookies
    #
    # Returns all the cookies for this domain/path. Path defaults to "/".
    this.cookies = (domain, path)-> cookies.access(domain, path)
    # ### brower.localStorage(host) => Storage
    #
    # Returns local Storage based on the document origin (hostname/port). This
    # is the same storage area you can access from any document of that origin.
    this.localStorage = (host)-> storage.local(host)
    # ### brower.sessionStorage(host) => Storage
    #
    # Returns session Storage based on the document origin (hostname/port). This
    # is the same storage area you can access from any document of that origin.
    this.sessionStorage = (host)-> storage.session(host)


    # Scripts
    # -------

    # ### browser.evaluate(function) : Object
    # ### browser.evaluate(code, filename) : Object
    #
    # Evaluates a JavaScript expression in the context of the current window
    # and returns the result.  When evaluating external script, also include
    # filename.
    #
    # You can also use this to evaluate a function in the context of the
    # window: for timers and asynchronous callbacks (e.g. XHR).
    this.evaluate = (code, filename)->
      if typeof code == "function"
        code.apply window
      else
        # Unfortunately, using the same context in multiple scripts
        # doesn't agree with jQuery, Sammy and other scripts I tested,
        # so each script gets a new context.
        context = vm.Script.createContext(window)
        # But we need to carry global variables from one script to the
        # next, so we're going to store them in window._vars and add them
        # back to the new context.
        if window._vars
          context[v[0]] = v[1] for v in @window._vars
        script = new vm.Script(code, filename || "eval")
        try
          return script.runInContext context
        catch ex
          this.log ex.stack.split("\n").slice(0,2)
          throw ex
        finally
          window._vars = ([n,v] for n, v of context).filter((v)-> !window[v[0]])


    # Interaction
    # -----------

    # ### browser.onalert(fn)
    #
    # Called by `window.alert` with the message.
    this.onalert = (fn)-> interact.onalert fn

    # ### browser.onconfirm(question, response)
    # ### browser.onconfirm(fn)
    #
    # The first form specifies a canned response to return when
    # `window.confirm` is called with that question.  The second form
    # will call the function with the question and use the respone of
    # the first function to return a value (true or false).
    #
    # The response to the question can be true or false, so all canned
    # responses are converted to either value.  If no response
    # available, returns false.
    this.onconfirm = (question, response)-> interact.onconfirm question, response

    # ### browser.onprompt(message, response)
    # ### browser.onprompt(fn)
    #
    # The first form specifies a canned response to return when
    # `window.prompt` is called with that message.  The second form will
    # call the function with the message and default value and use the
    # response of the first function to return a value or false.
    #
    # The response to a prompt can be any value (converted to a string),
    # false to indicate the user cancelled the prompt (returning null),
    # or nothing to have the prompt return the default value or an empty
    # string.
    this.onprompt = (message, response)-> interact.onprompt message, response

    # ### browser.prompted(message) => boolean
    #
    # Returns true if user was prompted with that message
    # (`window.alert`, `window.confirm` or `window.prompt`)
    this.prompted = (message)-> interact.prompted(message)


    # Debugging
    # ---------

    # ### browser.viewInBrowser(name?)
    #
    # Views the current document in a real Web browser.  Uses the default
    # system browser on OS X, BSD and Linux.  Probably errors on Windows.
    this.viewInBrowser = (browser)->
      require("./bcat").bcat @html()

    # ### browser.lastRequest => HTTPRequest
    #
    # Returns the last request sent by this browser. The object will have the
    # properties url, method, headers, and body.
    @__defineGetter__ "lastRequest", -> @window.resources.last?.request
    # ### browser.lastResponse => HTTPResponse
    #
    # Returns the last response received by this browser. The object will have the
    # properties url, status, headers and body. Long bodies may be truncated.
    @__defineGetter__ "lastResponse", -> @window.resources.last?.response
    # ### browser.lastError => Object
    #
    # Returns the last error received by this browser in lieu of response.
    @__defineGetter__ "lastError", -> @window.resources.last?.error

    # Zombie can spit out messages to help you figure out what's going
    # on as your code executes.
    #
    # To spit a message to the console when running in debug mode, call
    # this method with one or more values (same as `console.log`).  You
    # can also call it with a function that will be evaluated only when
    # running in debug mode.
    #
    # For example:
    #     browser.log("Opening page:", url);
    #     browser.log(function() { return "Opening page: " + url });
    this.log = ->
      if @debug
        values = ["Zombie:"]
        if typeof arguments[0] == "function"
          try
            values.push arguments[0]()
          catch ex
            values.push ex
        else
          values.push arg for arg in arguments
        console.log.apply null, values

    # Dump information to the consolt: Zombie version, current URL,
    # history, cookies, event loop, etc.  Useful for debugging and
    # submitting error reports.
    this.dump = ->
      indent = (lines)-> lines.map((l) -> "  #{l}\n").join("")
      console.log "Zombie: #{exports.version}\n"
      console.log "URL: #{@window.location.href}"
      console.log "History:\n#{indent history.dump()}"
      console.log "Cookies:\n#{indent cookies.dump()}"
      console.log "Storage:\n#{indent storage.dump()}"
      console.log "Eventloop:\n#{indent eventloop.dump()}"
      if @document
        html = @document.outerHTML
        html = html.slice(0, 497) + "..." if html.length > 497
        console.log "Document:\n#{indent html.split("\n")}"
      else
        console.log "No document" unless @document

    class Screen
      constructor: ->
        @width = 1280
        @height = 800
        @left = 0
        @top = 0

        @__defineGetter__ "availLeft", -> 0
        @__defineGetter__ "availTop", -> 0
        @__defineGetter__ "availWidth", -> @width
        @__defineGetter__ "availHeight", -> @height
        @__defineGetter__ "colorDepth", -> 24
        @__defineGetter__ "pixelDepth", -> 24

    # Always start with an open window.
    @open()

exports.Browser = Browser

# ### zombie.version : String
exports.package = JSON.parse(require("fs").readFileSync(__dirname + "/../../package.json"))
exports.version = exports.package.version
