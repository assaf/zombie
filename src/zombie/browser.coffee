jsdom = require("jsdom")
vm = process.binding("evals")
require "./jsdom_patches"
require "./forms"
require "./xpath"



# Use the browser to open up new windows and load documents.
#
# The browser maintains state for cookies and localStorage.
class Browser extends require("events").EventEmitter
  constructor: (options) ->
    cookies = require("./cookies").use(this)
    storage = require("./storage").use(this)
    eventloop = require("./eventloop").use(this)
    history = require("./history").use(this)
    xhr = require("./xhr").use(this)


    window = null
    # ### browser.open() => Window
    #
    # Open new browser window.
    this.open = ->
      window = jsdom.createWindow(jsdom.dom.level3.html)
      window.__defineGetter__ "browser", => this
      cookies.extend window
      storage.extend window
      eventloop.extend window
      history.extend window
      xhr.extend window
      window.JSON = JSON
      # Default onerror handler.
      window.onerror = (event)=> @emit "error", event.error || new Error("Error loading script")
      # TODO: Fix
      window.Image = ->
      return window
    # Always start with an open window.
    @open()

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


    # Events
    # ------

    # ### browser.wait(callback)
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
    # Events include timeout, interval and XHR `onreadystatechange`. DOM events
    # are handled synchronously.
    this.wait = (terminate, callback)->
      if !callback
        [callback, terminate] = [terminate, null]
      eventloop.wait window, terminate, (error) =>
        callback error, this if callback
      return

    # ### browser.fire(name, target, calback?)
    #
    # Fire a DOM event.  You can use this to simulate a DOM event, e.g. clicking a
    # link.  These events will bubble up and can be cancelled.  With a callback, this
    # method will call `wait`.
    #
    # * name -- Even name (e.g `click`)
    # * target -- Target element (e.g a link)
    # * callback -- Wait for events to be processed, then call me (optional)
    this.fire = (name, target, callback)->
      event = window.document.createEvent("HTMLEvents")
      event.initEvent name, true, true
      target.dispatchEvent event
      @wait callback if callback

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


    # Navigation
    # ----------

    # ### browser.visit(url, callback)
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
        onerror = (error)->
          @removeListener "error", onerror
          reset()
          callback error
        @on "error", onerror
        history._assign url
        @wait =>
          if @listeners("error").indexOf(onerror) >= 0
            @removeListener "error", onerror
            reset()
            callback null, this
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
        @fire "click", link, callback
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
      if field && field.tagName == "TEXTAREA" || (field.tagName == "INPUT" && TEXT_TYPES.indexOf(field.type) >= 0)
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
          field.checked = value
          @fire "change", field
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
      if(!option.selected)
        select = @xpath("./ancestor::select", option).value[0]
        option.selected = true
        @fire "change", select
      return this

    # ### browser.unselect(selector, value) => this
    #
    # Unselects an option.
    #
    # * selector -- CSS selector, field name or text of the field label
    # * value -- Value (or label) or option to select
    #
    # Returns this
    this.unselect = (selector, value)->
      option = findOption(selector, value)
      if(option.selected)
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
          @fire "click", button, callback
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

    # ### browser.evaluate(code, filename) : Object
    #
    # Evaluates a JavaScript expression in the context of the current window
    # and returns the result.  When evaluating external script, also include
    # filename.
    this.evaluate = (code, filename)->
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
        result = script.runInContext context
      catch ex
        this.log ex.stack.split("\n").slice(0,2)
        throw ex
      finally
        window._vars = ([n,v] for n, v of context).filter((v)-> !window[v[0]])
      result


    # Debugging
    # ---------

    # ### browser.viewInBrowser(name?)
    #
    # Views the current document in a real Web browser.  Uses the default
    # system browser on OS X, BSD and Linux.  Probably errors on Windows.
    this.viewInBrowser = (browser)->
      require("./bcat").bcat @html()

    trail = []
    this.record = (request)->
      trail.push pending = { request: request }
      pending
    # ### browser.last_request => Object
    #
    # Returns the last request sent by this browser. The object will have the
    # properties url, method, headers, and if applicable, body.
    @__defineGetter__ "lastRequest", -> trail[trail.length - 1]?.request
    # ### browser.last_response => Object
    #
    # Returns the last response received by this browser. The object will have the
    # properties status, headers and body. Long bodies may be truncated.
    @__defineGetter__ "lastResponse", -> trail[trail.length - 1]?.response
    # ### browser.last_error => Object
    #
    # Returns the last error received by this browser in lieu of response.
    @__defineGetter__ "lastError", -> trail[trail.length - 1]?.error

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


exports.Browser = Browser

# ### zombie.version : String
try
  exports.package = JSON.parse(require("fs").readFileSync(__dirname + "/../../package.json"))
  exports.version = exports.package.version
catch err
  console.log err
