jsdom = require("jsdom")
require "./jsdom_patches"
require "./sizzle"
require "./forms"

# Use the browser to open up new windows and load documents.
#
# The browser maintains state for cookies and localStorage.
class Browser
  constructor: ->
    # Start out with an empty window
    window = jsdom.createWindow(jsdom.dom.level3.html)
    window.browser = this
    # ### browser.window => Window
    #
    # Returns the main window.
    @__defineGetter__ "window", -> window
    # ### browser.document => Document
    #
    # Retursn the main window's document. Only valid after opening a document
    # (Browser.open).
    @__defineGetter__ "document", -> window.document


    # Cookies and storage.
    cookies = require("./cookies").use(this)
    window.cookies = cookies
    # ### browser.cookies => Cookies
    #
    # Returns all the cookies for this browser.
    @__defineGetter__ "cookies", -> cookies


    # Attach history/location objects to window/document.
    require("./history").attach this, window
    # ### browser.location => Location
    #
    # Return the location of the current document (same as window.location.href).
    @__defineGetter__ "location", -> window.location.href
    # ### browser.location = url
    #
    # Changes document location, loads new document if necessary (same as
    # setting window.location).
    @__defineSetter__ "location", (url)-> window.location = url


    # ### browser.clock
    #
    # The current clock time. Initialized to current system time when creating
    # a new browser, but doesn't advance except by setting it explicitly or
    # firing timeout/interval events.
    @clock = new Date().getTime()
    # ### browser.now => Date
    #
    # Date object with current time, based on browser clock.
    @__defineGetter__ "now", -> new Date(clock)
    require("./eventloop").attach this, window


    # All asynchronous processing handled by event loop.
    require("./xhr").attach this, window

    # TODO: Fix
    window.Image = ->

    # TODO: Fix
    responses = []
    @__defineGetter__ "response", -> responses[responses.length - 1]
    @__defineSetter__ "response", (response)-> responses.push response


    # Events
    # ------

    # ### browser.wait callback
    # ### browser.wait terminator, callback
    #
    # Process all events from the queue. This method returns immediately, events
    # are processed in the background. When all events are exhausted, it calls
    # the callback with null, browser; if any event fails, it calls the callback
    # with the exception.
    #
    # With one argument, that argument is the callback. With two arguments, the
    # first argument is a terminator and the last argument is the callback. The
    # terminator is one of:
    # - null -- process all events
    # - number -- process that number of events
    # - function -- called after each event, stop processing when function
    #   returns false
    #
    # Events include timeout, interval and XHR onreadystatechange. DOM events
    # are handled synchronously.
    this.wait = (terminate, callback)->
      if !callback
        callback = terminate
        terminate = null
      window.wait terminate, (err) => callback err, this
      return

    # ### browser.fire name, target, calback?
    #
    # Fire a DOM event. Some events are executed synchronously, but some incur
    # more work (loading resources, using timers, etc), in which case you'll want
    # to pass a callback.
    #
    # name -- Even name (e.g click)
    # target -- Target element (e.g a link)
    # callback -- Wait for events to be processed, then call me (optional)
    this.fire = (name, target, callback)->
      event = window.document.createEvent("HTMLEvents")
      event.initEvent name, true, true
      target.dispatchEvent event
      @wait callback if callback


    # Accessors
    # ---------

    # ### browser.find selector, context? => [Elements]
    #
    # Returns elements that match the selector, either from the document or the #
    # specified context element. Uses Sizzle.js, see
    # https://github.com/jeresig/sizzle/wiki.
    #
    # selector -- CSS selector
    # context -- Context element (if missing, uses document)
    # Returns an array of elements
    this.find = (selector, context)-> window.document?.find(selector, context)

    # ### browser.text selector, context? => String
    #
    # Returns the text contents of the selected elements. With no arguments,
    # returns the text contents of the document body.
    #
    # selector -- CSS selector
    # context -- Context element (if missing, uses document)
    # Returns a string
    this.text = (selector, context)->
      elements = @find(selector || "body", context)
      window.Sizzle?.getText(elements)

    # ### browser.html selector?, context? => String
    #
    # Returns the HTML contents of the selected elements. With no arguments,
    # returns the HTML contents of the document.
    #
    # selector -- CSS selector
    # context -- Context element (if missing, uses document)
    # Returns a string
    this.html = (selector, context)->
      if selector
        @find(selector, context).map((elem)-> elem.outerHTML).join("")
      else
        return window.document.outerHTML

    # ### browser.body => Element
    #
    # Returns the body Element of the current document.
    @__defineGetter__ "body", -> window.document?.find("body")[0]


    # Actions
    # -------

    # ### browser.open url, callback
    #
    # Loads document from the specified URL, and calls callback with null,
    # browser when done loading and processing events.
    #
    # If it fails to download, calls the callback with the error.
    this.open = (url, callback)->
      window.location = url
      window.addEventListener "error", (err)-> callback err
      window.document.addEventListener "DOMContentLoaded", => @wait callback
      return

    # ### browser.clickLink selector, callback
    #
    # Clicks on a link. Clicking on a link can trigger other events, load new #
    # page, etc: use a callback to be notified of completion.
    #
    # selector -- CSS selector or link text
    # callback -- Called with two arguments: error and browser
    this.clickLink = (selector, callback)->
      if link = @find(selector)[0]
        @fire "click", link, callback if link
        return
      for link in @find("body a")
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
      fields = @find(selector)
      return fields[0] if fields[0] && match(fields[0])
      # Use field name (case sensitive).
      fields = @find("[name='#{selector}']")
      return fields[0] if fields[0] && match(fields[0])
      # Try finding field from label.
      for label in @find("label")
        text = ""
        for c in label.children
          text = text + c.nodeValue if c.nodeType == 3
        if text.trim() == selector
          # Label can either reference field or enclose it
          if for_attr = label.getAttribute("for")
            fields = @find("#" + for_attr)
          else
            fields = @find("input, textarea, select", label)
          return fields[0] if fields[0] && match(fields[0])

    # ### browser.fill field, value
    #
    # Fill in a field: input field or text area.
    #
    # field -- CSS selector, field name or text of the field label
    # value -- Field value
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

    # ### browser.check field
    #
    # Checks a checkbox.
    #
    # field -- CSS selector, field name or text of the field label
    # Returns this
    this.check = (field)-> setCheckbox field, true

    # ### browser.check field
    #
    # Unchecks a checkbox.
    #
    # field -- CSS selector, field name or text of the field label
    # Returns this
    this.uncheck = (field)-> setCheckbox field, false

    # ### browser.choose field
    #
    # Selects a radio box option.
    #
    # field -- CSS selector, field value or text of the field label
    # Returns this
    this.choose = (field)->
      match = (elem)-> elem.nodeName == "INPUT" && elem.type?.toLowerCase() == "radio"
      input = findInput(field, match) || @find(":radio[value='#{field}']")[0]
      if input
        radios = @find(":radio[name='#{input.getAttribute("name")}']", input.form)
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

    # ### browser.select field, value
    #
    # Selects an option.
    #
    # field -- CSS selector, field name or text of the field label
    # value -- Value (or label) or option to select
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

    # ### browser.pressButton name, callback
    #
    # Press a button (button element of input type submit). Generally this will
    # submit the form. Use the callback to wait for the from submission, page
    # to load and all events run their course.
    #
    # name -- CSS selector, button name or text of BUTTON element
    # callback -- Called with two arguments: error and browser
    this.pressButton = (name, callback)->
      if button = @find(name).first
        button.click()
        return @wait(callback)
      for button in @find("form button")
        continue if button.getAttribute("disabled")
        if window.Sizzle.getText([button]).trim() == name
          @fire "click", button
          return @wait(callback)
      for input in @find("form :submit")
        continue if input.getAttribute("disabled")
        if input.name == name
          input.click()
          return @wait(callback)
      for input in @find("form :submit")
        continue if input.getAttribute("disabled")
        if input.value == name
          input.click()
          return @wait(callback)
      throw new Error("No BUTTON '#{name}'")


exports.Browser = Browser
