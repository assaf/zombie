{ brains, Browser } = require("./helpers")


describe "require.js", ->

  browser = null
  before (done)->
    browser = Browser.create()
    brains.ready(done)

  before ->
    brains.get "/requirejs", (req, res)->
      res.send """
      <html>
        <head>
          <script>
            var require = {
              paths: {
                main:   "/requirejs/index",
                jquery: "/jquery"
              }
            };
          </script>
          <script data-main="/requirejs/index" src="/scripts/require.js"></script>
        </head>
        <body>
          Hi there.
        </body>
      </html>
      """
    brains.get "/requirejs/index.js", (req, res)->
      res.send """
        define(["dependency"], function(dependency) {
          dependency()
        })
      """
    brains.get "/requirejs/dependency.js", (req, res)->
      res.send """
        define(["jquery"], function($) {
          return function() {
            document.title = "Dependency loaded";
            $("body").text("Hello");
          }
        })
      """

  before (done)->
    browser.visit("http://localhost:3003/requirejs", done)

  it "should load dependencies", ->
    browser.assert.text "title", "Dependency loaded"

  it "should run main module", ->
    browser.assert.text "body", "Hello"

  after ->
    browser.destroy()
