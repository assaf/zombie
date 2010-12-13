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
    fieldTypes = "email number password range search text url".split(" ")
    # Find input field from selector, name or label.
    findField = (selector, match)=>
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
      match = (field)-> field.nodeName == "TEXTAREA" || fieldTypes.indexOf(field.getAttribute("type")?.toLowerCase()) >= 0
      if field = findField(selector, match)
        if field.value != value
          field.value = value
          @fire "change", field
        return this
      throw new Error("No input matching the selector #{selector}")

    # Checks a checkbox.
    #
    # selector -- CSS selector, field name or text of the field label
    # Returns this
    @check = (selector)->
      match = (field)-> field.nodeName == "INPUT" && field.getAttribute("type").toLowerCase() == "checkbox"
      if field = findField(selector, match)
        unless field.checked
          field.checked = true
          @fire "change", field
        return this
      else
        throw new Error("No checkbox input matching the selector #{selector}")

    # Unchecks a checkbox.
    #
    # selector -- CSS selector, field name or text of the field label
    # Returns this
    @uncheck = (selector)->
      match = (field)-> field.nodeName == "INPUT" && field.getAttribute("type").toLowerCase() == "checkbox"
      if field = findField(selector, match)
        if field.checked
          field.checked = false
          @fire "change", field
        return this
      else
        throw new Error("No checkbox input matching the selector #{selector}")

    # Selects an option.
    #
    # selector -- CSS selector, field name or text of the field label
    # value -- Value (or label) or option to select
    # Returns this
    @select = (selector, value)->
      match = (field)-> field.nodeName == "SELECT"
      if field = findField(selector, match)
        for option in field.options
          if option.value == value
            if field.value != value
              field.value = value
              @fire "change", field
            return this
        for option in field.options
          if option.label == option.getAttribute("label")
            if field.value != value
              field.value = value
              @fire "change", field
            return this
        throw new Error("No option #{value}")
      else
        throw new Error("No select/options matching the selector #{selector}")

    # Selects a radio box option.
    #
    # selector -- CSS selector, field value or text of the field label
    # Returns this
    @choose = (selector)->
      match = (field)-> field.nodeName == "INPUT" && field.getAttribute("type").toLowerCase() == "radio"
      field = findField(selector, match) || @find(":radio[value='#{selector}']")[0]
      if field
        if !field.checked
          if form = field.form
            for radio in @find(":radio[name='#{field.getAttribute("name")}']", form)
              radio.checked = false
          field.checked = true
          @fire "change", field
        return this
      else
        throw new Error("No radio button matching the selector #{selector}")


exports.Browser = Browser
