{ assert, brains, Browser } = require("./helpers")


describe "XMLHttpRequest", ->

  browser = null
  before ->
    browser = Browser.create()

  describe "asynchronous", ->
    before (done)->
      brains.get "/xhr/async", (req, res)->
        res.send """
        <html>
          <head><script src="/jquery.js"></script></head>
          <body>
            <script>
              document.title = "One";
              window.foo = "bar";
              $.get("/xhr/async/backend", function(response) {
                window.foo += window.foo;
                document.title += response;
              });
              document.title += "Two";
            </script>
          </body>
        </html>
        """
      brains.get "/xhr/async/backend", (req, res)->
        res.send "Three"
      brains.ready done

    before (done)->
      browser.visit("http://localhost:3003/xhr/async", done)

    it "should load resource asynchronously", ->
      browser.assert.text "title", "OneTwoThree"
    it "should run callback in global context", ->
      browser.assert.global "foo", "barbar"


  describe "response headers", ->
    before (done)->
      brains.get "/xhr/headers", (req, res)->
        res.send """
        <html>
          <head><script src="/jquery.js"></script></head>
          <body>
            <script>
              $.get("/xhr/headers/backend", function(data, textStatus, jqXHR) {
                document.allHeaders = jqXHR.getAllResponseHeaders();
                document.headerOne = jqXHR.getResponseHeader('Header-One');
                document.headerThree = jqXHR.getResponseHeader('header-three');
              });
            </script>
          </body>
        </html>
        """
      brains.get "/xhr/headers/backend", (req, res)->
        res.setHeader "Header-One", "value1"
        res.setHeader "Header-Two", "value2"
        res.setHeader "Header-Three", "value3"
        res.send ""
      brains.ready done

    before (done)->
      browser.visit("http://localhost:3003/xhr/headers", done)

    it "should return all headers as string", ->
      assert ~browser.document.allHeaders.indexOf("header-one: value1\nheader-two: value2\nheader-three: value3")
    it "should return individual headers", ->
      assert.equal browser.document.headerOne, "value1"
      assert.equal browser.document.headerThree, "value3"


  describe "cookies", ->
    before (done)->
      brains.get "/xhr/cookies", (req, res)->
        res.cookie "xhr", "send", path: "/xhr"
        res.send """
        <html>
          <head><script src="/jquery.js"></script></head>
          <body>
            <script>
              $.get("/xhr/cookies/backend", function(cookie) {
                document.received = cookie;
              });
            </script>
          </body>
        </html>
        """
      brains.get "/xhr/cookies/backend", (req, res)->
        cookie = req.cookies["xhr"]
        res.cookie "xhr", "return", path: "/xhr"
        res.send cookie
      brains.ready done

    before (done)->
      browser.visit("http://localhost:3003/xhr/cookies", done)

    it "should send cookies to XHR request", ->
      assert.equal browser.document.received, "send"
    it "should return cookies from XHR request", ->
      assert /xhr=return/.test(browser.document.cookie)


  describe "redirect", ->
    before (done)->
      brains.get "/xhr/redirect", (req, res)-> res.send """
        <html>
          <head><script src="/jquery.js"></script></head>
          <body>
            <script>
              $.get("/xhr/redirect/backend", function(response) { window.response = response });
            </script>
          </body>
        </html>
        """
      brains.get "/xhr/redirect/backend", (req, res)->
        res.redirect "/xhr/redirect/target"
      brains.get "/xhr/redirect/target", (req, res)->
        res.send "redirected " + req.headers["x-requested-with"]
      brains.ready done

    before (done)->
      browser.visit("http://localhost:3003/xhr/redirect", done)

    it "should follow redirect", ->
      assert /redirected/.test(browser.window.response)
    it "should resend headers", ->
      assert /XMLHttpRequest/.test(browser.window.response)


  describe "handle POST requests with no data", ->
    before (done)->
      brains.get "/xhr/post/empty", (req, res)->
        res.send """
        <html>
          <head><script src="/jquery.js"></script></head>
          <body>
            <script>
              $.post("/xhr/post/empty", function(response, status, xhr) { document.title = xhr.status + response });
            </script>
          </body>
        </html>
        """
      brains.post "/xhr/post/empty", (req, res)->
        res.send "posted", 201
      brains.ready done

    before (done)->
      browser.visit("http://localhost:3003/xhr/post/empty", done)

    it "should post with no data", ->
      browser.assert.text "title", "201posted"


  describe "empty response", ->
    before (done)->
      brains.get "/xhr/get-empty", (req, res)->
        res.send """
        <html>
          <head><script src="/jquery.js"></script></head>
          <body>
            <script>
              $.get("/xhr/empty", function(response, status, xhr) {
                document.text = xhr.responseText;
              });
            </script>
          </body>
        </html>
        """
      brains.get "/xhr/empty", (req, res)->
        res.send ""
      brains.ready done

    before (done)->
      browser.visit("http://localhost:3003/xhr/get-empty", done)

    it "responseText should be an empty string", ->
      assert.strictEqual "", browser.document.text


  describe "response text", ->
    before (done)->
      brains.get "/xhr/get-utf8-octet-stream", (req, res)->
        res.send """
        <html>
          <head><script src="/jquery.js"></script></head>
          <body>
            <script>
              $.get("/xhr/utf8-octet-stream", function(response, status, xhr) {
                document.text = xhr.responseText;
              });
            </script>
          </body>
        </html>
        """
      brains.get "/xhr/utf8-octet-stream", (req, res)->
        res.type "application/octet-stream"
        res.send "Text"
      brains.ready done

    before (done)->
      browser.visit("http://localhost:3003/xhr/get-utf8-octet-stream", done)

    it "responseText should be a string", ->
      assert.equal "string", typeof browser.document.text
      assert.equal "Text", browser.document.text


  describe "CORS", ->
    before (done)->
      brains.get "/xhr/script-call-foreign-domain", (req, res)->
        res.send """
        <html>
         <head><script src="/jquery.js"></script></head>
         <body>
           Make a call to a foreign domain
           <script>
            // Make the x-domain jsonp request...
            $.support.cors = true;
            $.ajax({
                url: 'http://localhost:3010/json',
                type: 'GET',
                success: function(message,text,response){
                  document.corsHeader = response.getResponseHeader('Access-Control-Allow-Origin')
                  document.text = message;
                },
                error: function(message,text,response) {
                  document.error = response;
                }
            });
           </script>
         </body>
        </html>
        """

      brains.get '/json', (req,res)->
        res.type "application/json"
        res.setHeader 'Access-Control-Allow-Origin', 'localhost:3003'
        res.send {some:"object"}

      brains.options '/*', (req,res)->
        res.setHeader 'Access-Control-Allow-Origin', 'localhost:3003'
        res.send 200

      brains.ready ->
        brains.ready done

    before (done)->
      browser.visit("http://localhost:3003/xhr/script-call-foreign-domain", {debug:true}, done)

    it "should be able to do x-domain req with appropriate headers", ->
      console.log browser.document.error
      console.log browser.document.corsHeader
      assert.equal '{"some":"object"}', JSON.stringify(browser.document.text)



  describe.skip "HTML document", ->
    before (done)->
      brains.get "/xhr/get-html", (req, res)->
        res.send """
        <html>
          <head><script src="/jquery.js"></script></head>
          <body>
            <script>
              $.get("/xhr/html", function(response, status, xhr) {
                document.body.appendChild(xhr.responseXML);
              });
            </script>
          </body>
        </html>
        """
      brains.get "/xhr/html", (req, res)->
        res.type("text/html")
        res.send("<foo><bar id='bar'></foo>")
      brains.ready done

    before (done)->
      browser.visit("http://localhost:3003/xhr/get-html", done)

    it "should parse HTML document", ->
      browser.assert.element "foo > bar#bar"


  after ->
    browser.destroy()