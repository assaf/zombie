require.paths.unshift(__dirname)
fs = require("fs")
jsdom = require("jsdom")
require "./jsdom_patches"

# Use the browser to open up new windows and load documents.
#
# The browser maintains state for cookies and localStorage.
class Browser
  constructor: ->
    # Start out with an empty window
    window = jsdom.createWindow(jsdom.dom.level3.html)
    window.browser = this
    # Attach history/location objects to window/document.
    require("./history").apply(window)
    # All asynchronous processing handled by event loop.
    require("./xhr").apply(window)
    require("./eventloop").apply(window)
    # Add Sizzle, default event handling, etc
    require("./document").apply(window)

    # Loads document from the specified URL, and calls callback with null,
    # browser when done loading (corresponds to DOMContentLoaded event).
    #
    # If it fails to download, calls the callback with the error.
    @open = (url, callback)->
      window.location = url
      window.addEventListener "error", (err)-> callback err
      window.document.addEventListener "DOMContentLoaded", =>
        process.nextTick => callback null, this
      return

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
    @wait = (terminate, callback)->
      if !callback
        callback = terminate
        terminate = null
      window.wait terminate, (err) => callback err, this
      return

    # Fire a DOM event. Some events are executed synchronously, but some incur
    # more work (loading resources, using timers, etc), in which case you'll want
    # to pass a callback.
    #
    # name -- Even name (e.g click)
    # target -- Target element (e.g a link)
    # callback -- Wait for events to be processed, then call me (optional)
    @fire = (name, target, callback)->
      event = window.document.createEvent("HTMLEvents")
      event.initEvent name, true, true
      target.dispatchEvent event
      @wait callback if callback

    # Returns elements that match the selector, either from the document or the #
    # specified context element. Uses Sizzle.js, see
    # https://github.com/jeresig/sizzle/wiki.
    #
    # selector -- CSS selector
    # context -- Context element (if missing, uses document)
    @find = (selector, context)-> window.find(selector, context)


    # The main window.
    @__defineGetter__ "window", -> window
    # The main window's document. Only valid after opening a document
    # (Browser.open).
    @__defineGetter__ "document", -> window.document
    # Location of the current document (same as window.location.href).
    @__defineGetter__ "location", -> window.location.href
    # Changes document location, loads new document if necessary (same as
    # setting window.location).
    @__defineSetter__ "location", (url)-> window.location = url
    # Returns the HTML contents of the current document as a string.
    @__defineGetter__ "html", -> window.document.outerHTML
    # Returns the body Element of the current document.
    @__defineGetter__ "body", -> window.Sizzle("body")[0]


    # ----- Actions -----

    # Clicks on a link. Clicking on a link can trigger other events, load new #
    # page, etc: use a callback to be notified of completion.
    #
    # selector -- CSS selector or link text
    # callback -- Called with null, browser or error
    @clickLink = (selector, callback)->
      if link = @find(selector)[0]
        @fire "click", link, callback if link
        return
      for link in @find("body a")
        if window.Sizzle.getText([link]).trim() == selector
          @fire "click", link, callback
          return
      return


    # ----- Forms -----

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

    # Fill in a field: input field or text area.
    #
    # selector -- CSS selector, field name or text of the field label
    # value -- Field value
    # Returns this
    @fill = (selector, value)->
      match = (elem)-> elem.nodeName == "TEXTAREA" || textTypes.indexOf(elem.type?.toLowerCase()) >= 0
      if input = findInput(selector, match)
        throw new Error("This INPUT field is disabled") if input.getAttribute("input")
        throw new Error("This INPUT field is readonly") if input.getAttribute("readonly")
        input.value = value
        @fire "change", input
        return this
      throw new Error("No INPUT matching '#{selector}'")

    setCheckbox = (selector, state)=>
      match = (elem)-> elem.nodeName == "INPUT" && elem.type == "checkbox"
      if input = findInput(selector, match)
        throw new Error("This INPUT field is disabled") if input.getAttribute("input")
        throw new Error("This INPUT field is readonly") if input.getAttribute("readonly")
        input.checked = state
        @fire "change", input
        @fire "click", input
        return this
      else
        throw new Error("No checkbox INPUT matching '#{selector}'")

    # Checks a checkbox.
    #
    # selector -- CSS selector, field name or text of the field label
    # Returns this
    @check = (selector)-> setCheckbox selector, true

    # Unchecks a checkbox.
    #
    # selector -- CSS selector, field name or text of the field label
    # Returns this
    @uncheck = (selector)-> setCheckbox selector, false

    # Selects a radio box option.
    #
    # selector -- CSS selector, field value or text of the field label
    # Returns this
    @choose = (selector)->
      match = (elem)-> elem.nodeName == "INPUT" && elem.type?.toLowerCase() == "radio"
      input = findInput(selector, match) || @find(":radio[value='#{selector}']")[0]
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
        throw new Error("No radio INPUT matching '#{selector}'")

    # Selects an option.
    #
    # selector -- CSS selector, field name or text of the field label
    # value -- Value (or label) or option to select
    # Returns this
    @select = (selector, value)->
      match = (elem)-> elem.nodeName == "SELECT"
      if select = findInput(selector, match)
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
        throw new Error("No OPTION #{value}")
      else
        throw new Error("No SELECT matching '#{selector}'")

exports.Browser = Browser
