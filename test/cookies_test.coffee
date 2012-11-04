{ assert, brains, Browser } = require("./helpers")


describe "Cookies", ->

  # Parse string with cookies in it (like document.cookies) and return object
  # with name/value pairs for each cookie.
  parse = (cookies)->
    return cookies
      .split(/;\s*/)
      .map((cookie)-> cookie.split("="))
      .reduce((all, [name, value])->
          all[name] = value.replace(/^"(.*)"$/, "$1")
          all
        , Object.create({}))

  # Extracts cookies from @browser, parses and sets @cookies.
  cookies_from_html = ->
    @cookies = parse(@browser.text("html"))
    return


  before (done)->
    brains.get "/cookies", (req, res)->
      res.cookie "_name",     "value"
      res.cookie "_expires1", "3s",       expires: new Date(Date.now() + 3000)
      res.cookie "_expires2", "5s",       "Max-Age": 5000
      res.cookie "_expires3", "0s",       expires: new Date(Date.now() - 100)
      res.cookie "_path1",    "yummy",    path: "/cookies"
      res.cookie "_path2",    "yummy",    path: "/cookies/sub"
      res.cookie "_path3",    "wrong",    path: "/wrong"
      res.cookie "_path4",    "yummy",    path: "/"
      res.cookie "_domain1",  "here",     domain: ".localhost"
      res.cookie "_domain2",  "not here", domain: "not.localhost"
      res.cookie "_domain3",  "wrong",    domain: "notlocalhost"
      res.cookie "_multiple", "specific", path: "/cookies"
      res.cookie "_multiple", "general",  path: "/"
      res.cookie "_http_only","value",    httpOnly: true
      res.cookie "_dup",      "one",      path: "/"
      res.send "<html></html>"

    brains.get "/cookies/echo", (req,res)->
      cookies = ("#{k}=#{v}" for k,v of req.cookies).join("; ")
      res.send "<html>#{cookies}</html>"

    brains.get "/cookies/empty", (req,res)->
      res.send "<html></html>"

    brains.ready done


  describe "get cookies", ->

    before (done)->
      @browser = new Browser()
      @browser.visit "http://localhost:3003/cookies", done

    describe "cookies", ->
      it "should have access to session cookie", ->
        @browser.assert.cookie "_name", "value"
      it "should have access to persistent cookie", ->
        @browser.assert.cookie "_expires1", "3s"
        @browser.assert.cookie "_expires2", "5s"
      it "should not have access to expired cookies", ->
        @browser.assert.cookie "_expires3", undefined
      it "should have access to cookies for the path /cookies", ->
        @browser.assert.cookie "_path1", "yummy"
      it "should have access to cookies for paths which are ancestors of /cookies", ->
        @browser.assert.cookie "_path4", "yummy"
      it "should not have access to other paths", ->
        @browser.assert.cookie "_path2", undefined
        @browser.assert.cookie "_path3", undefined
      it "should have access to .domain", ->
        @browser.assert.cookie "_domain1", "here"
      it "should not have access to other domains", ->
        @browser.assert.cookie "_domain2", undefined
        @browser.assert.cookie "_domain3", undefined
      it "should access most specific cookie", ->
        @browser.assert.cookie "_multiple", "specific"


    describe "host in domain", ->
      it "should have access to host cookies", ->
        @browser.assert.cookie "_domain1", "here"
      it "should not have access to other hosts' cookies", ->
        @browser.assert.cookie "_domain2", undefined
        @browser.assert.cookie "_domain3", undefined

    describe "document.cookie", ->
      before ->
        @cookie = @browser.document.cookie

      it "should return name/value pairs", ->
        assert /^(\w+=\w+; )+\w+=\w+$/.test(@cookie)

      describe "pairs", ->
        before ->
          @pairs = parse(@cookie)

        it "should include only visible cookies", ->
          keys = (key for key, value of @pairs).sort()
          assert.deepEqual keys, "_domain1 _dup _expires1 _expires2 _multiple _name _path1 _path4".split(" ")
        it "should match name to value", ->
         assert.equal @pairs._name, "value"
         assert.equal @pairs._path1, "yummy"
        it "should not include httpOnly cookies", ->
          for key, value of @pairs
            assert key != "_http_only"


  describe "host", ->

    before (done)->
      browser = new Browser()
      browser.visit("http://host.localhost:3003/cookies")
        .then =>
          @cookies = browser.cookies("localhost", "/cookies")
          return
        .then(done, done)

    it "should be able to set domain cookies", ->
      assert.equal @cookies.get("_domain1"), "here"


  describe "get cookies and redirect", ->

    before (done)->
      brains.get "/cookies/redirect", (req, res)->
        res.cookie "_expires4", "3s" #, expires: new Date(Date.now() + 3000), "Path": "/"
        res.redirect "/"

      browser = new Browser()
      browser.visit("http://localhost:3003/cookies/redirect")
        .then =>
          @cookies = browser.cookies("localhost", "/cookies/redirect")
          return
        .then(done, done)

    it "should have access to persistent cookie", ->
      assert.equal @cookies.get("_expires4"), "3s"


  describe "duplicates", ->

    before (done)->
      brains.get "/cookies2", (req, res)->
        res.cookie "_dup", "two", path: "/"
        res.send ""
      brains.get "/cookies3", (req, res)->
        res.cookie "_dup", "three", path: "/"
        res.send ""

      @browser = new Browser()
      @browser.visit("http://localhost:3003/cookies")
        .then =>
          @browser.visit "http://localhost:3003/cookies2"
        .then =>
          @browser.visit "http://localhost:3003/cookies3"
        .then(done, done)

    it "should retain last value", ->
      assert.equal @browser.cookies().get("_dup"), "three"
    it "should only retain last cookie", ->
      dups = @browser.cookies().all().filter((c)-> c.key == "_dup")
      assert.equal dups.length, 1


  describe "send cookies", ->

    before (done)->
      @browser = new Browser()
      @browser.cookies("localhost"                   ).set "_name",      "value"
      @browser.cookies("localhost"                   ).set "_expires1",  "3s",     "max-age": 3000
      @browser.cookies("localhost"                   ).set "_expires2",  "0s",     "max-age": 0
      @browser.cookies("localhost", "/cookies"       ).set "_path1",     "here"
      @browser.cookies("localhost", "/cookies/echo"  ).set "_path2",     "here"
      @browser.cookies("localhost", "/jars"          ).set "_path3",     "there",  "path": "/jars"
      @browser.cookies("localhost", "/cookies/fido"  ).set "_path4",     "there",  "path": "/cookies/fido"
      @browser.cookies("localhost", "/"              ).set "_path5",     "here",   "path": "/cookies"
      @browser.cookies("localhost", "/jars/"         ).set "_path6",     "there"
      @browser.cookies(".localhost"                  ).set "_domain1",   "here"
      @browser.cookies("not.localhost"               ).set "_domain2",   "there"
      @browser.cookies("notlocalhost"                ).set "_domain3",   "there"
      @browser.visit("http://localhost:3003/cookies/echo")
        .then(cookies_from_html.bind(this))
        .then(done, done)

    it "should send session cookie", ->
      @browser.assert.cookie "_name", "value"
    it "should pass persistent cookie to server", ->
      @browser.assert.cookie "_expires1", "3s"
    it "should not pass expired cookie to server", ->
      @browser.assert.cookie "_expires2", undefined
    it "should pass path cookies to server", ->
      @browser.assert.cookie "_path1", "here"
      @browser.assert.cookie "_path2", "here"
    it "should pass cookies that specified a different path when they were assigned", ->
      @browser.assert.cookie "_path5", "here"
    it "should not pass unrelated path cookies to server", ->
      @browser.assert.cookie "_path3", undefined
      @browser.assert.cookie "_path4", undefined
      @browser.assert.cookie "_path6", undefined
    it "should pass sub-domain cookies to server", ->
      @browser.assert.cookie "_domain1", "here"
    it "should not pass other domain cookies to server", ->
      @browser.assert.cookie "_domain2", undefined
      @browser.assert.cookie "_domain3", undefined


  describe "setting cookies from subdomains", ->
    before ->
      @browser = new Browser()
      @browser.cookies("www.localhost").update("foo=bar; domain=.localhost")
      
    it "should be accessible", ->
      assert.equal "bar", @browser.cookies("localhost").get("foo")
      assert.equal "bar", @browser.cookies("www.localhost").get("foo")


  describe "setting Cookie header", ->
    before ->
      @header = { cookie: "" }
      browser = new Browser()
      browser.cookies().update("foo=bar;")
      browser.cookies().addHeader @header
      
    it "should send V0 header", ->
      assert.equal @header.cookie, "foo=bar"


  describe "document.cookie", ->

    describe "setting cookie", ->
      before (done)->
        @browser = new Browser()
        @browser.visit("http://localhost:3003/cookies")
          .then =>
            @browser.document.cookie = "foo=bar"
            return
          .then(done, done)

      it "should be available from document", ->
        assert ~@browser.document.cookie.split("; ").indexOf("foo=bar")

      describe "on reload", ->
        before (done)->
          @browser.visit("http://localhost:3003/cookies/echo")
            .then(cookies_from_html.bind(this))
            .then(done, done)

        it "should send to server", ->
          assert.equal @cookies.foo, "bar"

      describe "different path", ->
        before (done)->
          @browser.visit("http://localhost:3003/cookies")
            .then =>
              @browser.document.cookie = "foo=bar"
              return
            .then(done, done)

        before (done)->
          @browser.visit("http://localhost:3003/cookies/other")
            .then =>
              @browser.document.cookie = "foo=qux" # more specific path, not visible to /cookies.echo
              return
            .finally(done)

        before (done)->
          @browser.visit("http://localhost:3003/cookies/echo")
            .then(cookies_from_html.bind(this))
            .then(done, done)

        it "should not be visible", ->
          assert !@cookies.bar
          assert.equal @cookies.foo, "bar"


    describe "setting cookie with quotes", ->
      before (done)->
        @browser.visit("http://localhost:3003/cookies/empty")
          .then =>
            @browser.document.cookie = "foo=bar\"baz"
            return
          .then(done, done)

      it "should be available from document", ->
        @browser.assert.cookie "foo", "bar\"baz"


    describe "setting cookie with semicolon", ->
      before (done)->
        @browser.visit("http://localhost:3003/cookies/empty")
          .then =>
            @browser.document.cookie = "foo=bar; baz"
            return
          .then(done, done)

      it "should be available from document", ->
        @browser.assert.cookie "foo", "bar"
