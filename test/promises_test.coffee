{ assert, brains, Browser } = require("./helpers")


describe "Promises", ->

  browser = null
  before (done)->
    browser = Browser.create()
    brains.ready(done)


  before ->
    brains.get "/promises", (req, res)->
      res.send """
      <script>document.title = "Loaded"</script>
      """


  # The simplest promise looks like this:
  #
  #    browser.visit("/promises")
  #      .then(done, done)
  #
  # The first done callback is called with no arguments if the promise resolves
  # successfully.  The second done callback is called with an error if the
  # promise is rejected, causing the test to fail.

  describe "visit", ->
    before (done)->
      browser.visit("/promises")
        .then(done, done)

    it "should resolve when page is done loading", ->
      browser.assert.text "title", "Loaded"


    # You can chain multiple promises together, each one is used to
    # resolve/reject the next one.
    #
    # In CoffeeScript, a function that doesn't end with return statement will
    # return the value of the last statement.
    #
    # In the first step we have explicit return, that value is used to resolve
    # the next promise.
    #
    # In the second step we have implicit return.
    #
    # In the third step we have an implicit return of a promise.  This works out
    # like you expect, resolving of that promise takes us to the fourth step.
    describe "chained", ->
      before (done)->
        browser.visit("/promises")
          .then ->
            # This value is used to resolve the next value
            return "Then"
          .then (value)->
            browser.document.title = value
          .then (value)->
            assert.equal value, "Then"
            # The document title changes only if we wait for the event loop
            browser.window.setTimeout ->
              @document.title = "Later"
            , 0
            # This promise is used to resolve the next one
            return browser.wait()
          .then(done, done)

      it "should resolve when page is done loading", ->
        browser.assert.text "title", "Later"


  # In practice you would do something like:
  #
  #   browser.visit("/promises")
  #     .then ->
  #       browser.fill "Email", "armbiter@example.com"
  #       browser.fill "Password", "b100d"
  #     .then ->
  #       browser.pressButton "Let me in"
  #     .then done, done
  describe "error", ->
    before (done)->
      browser.visit("/promises/nosuch")
        .then(done)
        .fail (@error)=>
          done()

    it "should reject with an error", ->
      assert ~@error.message.search("Server returned status code 404")


  # In practice you would do something like:
  #
  #   browser.visit("/promises")
  #     .then ->
  #       assert.equal browser.document.title, "What I expected"
  #     .then done, done
  describe "failed assertion", ->
    before (done)->
      browser.visit("/promises")
        .then ->
          browser.assert.text "title", "Ooops", "Assertion haz a fail"
        .fail (@error)=>
          done()

    it "should reject with an error", ->
      assert.equal @error.message, "Assertion haz a fail"


  # Chaining allows us to capture errors once at the very end of the chain.
  #
  # Here we expect an error to happen and that should pass the test.
  #
  # If an error doesn't happen, we call done with a value and that would fail
  # the test.
  describe "chained", ->
    before (done)->
      browser.visit("/promises")
        .then ->
          browser.assert.text "title", "Ooops", "Assertion haz a fail"
        .then ->
          browser.assert.text "title", "Ooops", "I'm here against all odds"
        .then ->
          browser.assert.text "title", "Ooops", "I'm here against all odds"
        .fail (@error)=>
          done()

    it "should reject with an error", ->
      assert.equal @error.message, "Assertion haz a fail"


  after ->
    browser.destroy()
