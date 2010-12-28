jsdom = require("jsdom")
require "./jsdom_patches"
require "./sizzle"
require "./forms"


# Use the browser to open up new windows and load documents.
#
# The browser maintains state for cookies and localStorage.
class Browser extends require("events").EventEmitter
  constructor: ->
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
      # TODO: Fix
      window.Image = ->
      window.JSON = JSON
      return window
    # Always start with an open window.
    @open()


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
        callback = terminate
        terminate = null
      eventloop.wait window, terminate, (error) =>
        callback error, this if callback
      return

    # ### browser.fire(name, target, calback?)
    #
    # Fire a DOM event.  You can use this to simulate a DOM event, e.g. clicking a
    # link.  These events will bubble up and can be cancelled.  With a callback, this
    # function will call `wait`.
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
    @__defineGetter__ "now", -> new Date(clock)


    # Accessors
    # ---------

    # ### browser.querySelector(selector) => Element
    #
    # Select a single element (first match) and return it.
    #
    # * selector -- CSS selector
    #
    # Returns an Element or null
    this.querySelector = (selector)-> window.document?.querySelector(selector)

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
      elements = if selector then (context || @document).querySelectorAll(selector).toArray() else [@document]
      elements.map((e)-> e.textContent).join("")

    # ### browser.html(selector?, context?) => String
    #
    # Returns the HTML contents of the selected elements.
    #
    # * selector -- CSS selector (if missing, entire document)
    # * context -- Context element (if missing, uses document)
    #
    # Returns a string
    this.html = (selector, context)->
      elements = if selector then (context || @document).querySelectorAll(selector).toArray() else [@document]
      elements.map((e)-> e.outerHTML.trim()).join("")

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
    #
    # Loads document from the specified URL, processes events and calls the
    # callback.
    #
    # If it fails to download, calls the callback with the error.
    this.visit = (url, callback)->
      @on "error", (error)->
        @removeListener "error", arguments.callee
        callback error
      history._assign url
      window.document.addEventListener "DOMContentLoaded", => @wait callback
      return

    # ### browser.location => Location
    #
    # Return the location of the current document (same as `window.location.href`).
    @__defineGetter__ "location", -> window.location.href
    # ### browser.location = url
    #
    # Changes document location, loads new document if necessary (same as
    # setting `window.location`).
    @__defineSetter__ "location", (url)-> window.location = url
    

    # Forms
    # -----

    # ### browser.clickLink(selector, callback)
    #
    # Clicks on a link. Clicking on a link can trigger other events, load new
    # page, etc: use a callback to be notified of completion.  Finds link by
    # text content or selector.
    #
    # * selector -- CSS selector or link text
    # * callback -- Called with two arguments: error and browser
    this.clickLink = (selector, callback)->
      if link = @querySelector(selector)
        @fire "click", link, callback if link
        return
      for link in @querySelectorAll("body a")
        if window.Sizzle.getText([link]).trim() == selector
          @fire "click", link, callback
          return
      return


    # Forms
    # -----

    # HTML5 field types that you can "fill in".
    textTypes = "email number password range search text url".split(" ")
    # Find input field from selector, name or label.
    findInput = (selector, match)=>
      # Try more specific selector first.
      field = @querySelector(selector)
      return field if field && match(field)
      # Use field name (case sensitive).
      field = @querySelector("[name='#{selector}']")
      return field if field && match(field)
      # Try finding field from label.
      for label in @querySelectorAll("label")
        if label.textContent.trim() == selector
          # Label can either reference field or enclose it
          if for_attr = label.getAttribute("for")
            field = @querySelector("#" + for_attr)
          else
            field = label.querySelector("input, textarea, select")
          return field if field && match(field)
      return

    # ### browser.fill(field, value) => this
    #
    # Fill in a field: input field or text area.
    #
    # * field -- CSS selector, field name or text of the field label
    # * value -- Field value
    #
    # Returns this
    this.fill = (field, value)->
      match = (elem)-> elem.nodeName == "TEXTAREA" || textTypes.indexOf(elem.type?.toLowerCase()) >= 0
      if input = findInput(field, match)
        throw new Error("This INPUT field is disabled") if input.getAttribute("input")
        throw new Error("This INPUT field is readonly") if input.getAttribute("readonly")
        input.value = value
        @fire "change", input
        return this
      throw new Error("No INPUT matching '#{field}'")

    setCheckbox = (field, state)=>
      match = (elem)-> elem.nodeName == "INPUT" && elem.type == "checkbox"
      if input = findInput(field, match)
        throw new Error("This INPUT field is disabled") if input.getAttribute("input")
        throw new Error("This INPUT field is readonly") if input.getAttribute("readonly")
        input.checked = state
        @fire "change", input
        @fire "click", input
        return this
      else
        throw new Error("No checkbox INPUT matching '#{field}'")

    # ### browser.check(field) => this
    #
    # Checks a checkbox.
    #
    # * field -- CSS selector, field name or text of the field label
    #
    # Returns this
    this.check = (field)-> setCheckbox field, true

    # ### browser.uncheck(field) => this
    #
    # Unchecks a checkbox.
    #
    # * field -- CSS selector, field name or text of the field label
    #
    # Returns this
    this.uncheck = (field)-> setCheckbox field, false

    # ### browser.choose(field) => this
    #
    # Selects a radio box option.
    #
    # * field -- CSS selector, field value or text of the field label
    #
    # Returns this
    this.choose = (field)->
      match = (elem)-> elem.nodeName == "INPUT" && elem.type?.toLowerCase() == "radio"
      input = findInput(field, match) || @querySelector(":radio[value='#{field}']")
      if input
        radios = @querySelectorAll(":radio[name='#{input.getAttribute("name")}']", input.form)
        for radio in radios
          throw new Error("This INPUT field is disabled") if radio.getAttribute("input")
          throw new Error("This INPUT field is readonly") if radio.getAttribute("readonly")
        radio.checked = false for radio in radios
        input.checked = true
        @fire "change", input
        @fire "click", input
        return this
      else
        throw new Error("No radio INPUT matching '#{field}'")

    # ### browser.select(field, value) => this
    #
    # Selects an option.
    #
    # * field -- CSS selector, field name or text of the field label
    # * value -- Value (or label) or option to select
    #
    # Returns this
    this.select = (field, value)->
      match = (elem)-> elem.nodeName == "SELECT"
      if select = findInput(field, match)
        throw new Error("This SELECT field is disabled") if select.getAttribute("disabled")
        for option in select.options
          if option.value == value
            select.value = option.value
            @fire "change", select
            return this
        for option in select.options
          if option.label == value
            select.value = option.value
            @fire "change", select
            return this
        throw new Error("No OPTION '#{value}'")
      else
        throw new Error("No SELECT matching '#{field}'")

    # ### browser.pressButton(name, callback)
    #
    # Press a button (button element or input of type `submit`).  Typically
    # this will submit the form.  Use the callback to wait for the from
    # submission, page to load and all events run their course.
    #
    # * name -- CSS selector, button name or text of BUTTON element
    # * callback -- Called with two arguments: error and browser
    this.pressButton = (name, callback)->
      if button = @querySelector(name)
        button.click()
        return @wait(callback)
      for button in @querySelectorAll("form button")
        continue if button.getAttribute("disabled")
        if window.Sizzle.getText([button]).trim() == name
          @fire "click", button
          return @wait(callback)
      inputs = @querySelectorAll("form :submit, form :reset, form :button")
      for input in inputs
        continue if input.getAttribute("disabled")
        if input.name == name
          input.click()
          return @wait(callback)
      for input in inputs
        continue if input.getAttribute("disabled")
        if input.value == name
          input.click()
          return @wait(callback)
      throw new Error("No BUTTON '#{name}'")


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


    # Debugging
    # ---------

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

    debug = false
    # Zombie can spit out messages to help you figure out what's going
    # on as your code executes.
    #
    # To turn debugging on, call this method with true; to turn it off,
    # call with false.  You can also call with a setting and a function,
    # in which case it will turn debugging on or off, execute the function
    # and then switch it back to its current settings.
    #
    # For example:
    #     browser.debug(true, function() {
    #       // Need to you be verbose here
    #       ...
    #     });
    #
    # To spit a message to the console when running in debug mode, call
    # this method with one or more values (same as `console.log`).  You
    # can also call it with a function that will be evaluated only when
    # running in debug mode.
    #
    # For example:
    #     browser.debug("Opening page:", url);
    #     browser.debug(function() { return "Opening page: " + url });
    #
    # With no arguments returns the current debug state.
    this.debug = ->
      return debug if arguments.length == 0
      if typeof arguments[0] == "boolean"
        old = debug
        debug = arguments[0]
        if typeof arguments[1] == "function"
          try
            arguments[1]()
          finally
            debug = old
      else if debug
        fields = ["Zombie:"]
        if typeof arguments[0] == "function"
          fields.push arguments[0]()
        else if debug
          fields.push arg for arg in arguments
        console.log.apply null, fields

    this.dump = ->
      indent = (lines)-> lines.map((l) -> "  #{l}\n").join("")
      console.log "URL: #{@window.location.href}"
      console.log "History:\n#{indent history.dump()}"
      console.log "Cookies:\n#{indent cookies.dump()}"
      console.log "Storage:\n#{indent storage.dump()}"
      if @document
        html = @document.outerHTML
        html = html.slice(0, 497) + "..." if html.length > 497
        console.log "Document:\n#{indent html.split("\n")}"
      else
        console.log "No document" unless @document


exports.Browser = Browser
