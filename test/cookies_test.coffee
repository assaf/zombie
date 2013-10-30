{ assert, brains, Browser } = require("./helpers")


describe "Cookies", ->

  browser = null
  before (done)->
    browser = Browser.create()
    brains.ready(done)

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
  cookiesFromHtml = (browser)->
    return parse(browser.source)


  # -- Browser API --


  describe "getCookie", ->
    before ->
      browser.deleteCookies()
      browser.setCookie(name: "foo", domain: ".example.com",               value: "partial domain")
      browser.setCookie(name: "foo", domain: "www.example.com",            value: "full domain")
      browser.setCookie(name: "foo", domain: ".example.com", path: "/bar", value: "full path")

    it "should find cookie by name", ->
      browser.visit("http://example.com/")
      assert.equal browser.getCookie("foo"), "partial domain"
      browser.close()

    it "should find cookie with most specific domain", ->
      assert.equal browser.getCookie(name: "foo", domain: "dox.example.com"), "partial domain"
      assert.equal browser.getCookie(name: "foo", domain: "example.com"),     "partial domain"
      assert.equal browser.getCookie(name: "foo", domain: "www.example.com"), "full domain"

    it "should find cookie with most specific path", ->
      assert.equal browser.getCookie(name: "foo", domain: "example.com", path: "/"),     "partial domain"
      assert.equal browser.getCookie(name: "foo", domain: "example.com", path: "/bar"),  "full path"

    it "should return cookie object if second argument is true", ->
      assert.deepEqual browser.getCookie(name: "foo", domain: "www.example.com", true),
        name:   "foo"
        value:  "full domain"
        domain: "www.example.com"
        path:   "/"

    it "should return null if no match", ->
      assert.equal browser.getCookie(name: "unknown", domain: "example.com"), null

    it "should return null if no match and second argument is true", ->
      assert.equal browser.getCookie(name: "unknown", domain: "example.com", true), null

    it "should fail if no domain specified", ->
      assert.throws ->
        assert.equal browser.getCookie("no-domain")
      , "No domain specified and no open page"


  describe "deleteCookie", ->
    describe "by name", ->
      before ->
        browser.deleteCookies()
        browser.visit("http://example.com/")
        browser.setCookie("foo", "delete me")
        browser.setCookie("bar", "keep me")

      it "should delete that cookie", ->
        browser.assert.cookie("foo", "delete me")
        assert browser.deleteCookie("foo")
        browser.assert.cookie("foo", null)
        browser.assert.cookie("bar", "keep me")

      after ->
        browser.close()

    describe "by name and domain", ->
      before ->
        browser.deleteCookies()
        browser.setCookie(name: "foo", domain: "www.example.com", value: "delete me")
        browser.setCookie(name: "foo", domain: ".example.com",    value: "keep me")

      it "should delete that cookie", ->
        browser.assert.cookie(name: "foo", domain: "www.example.com", "delete me")
        assert browser.deleteCookie(name: "foo", domain: "www.example.com")
        browser.assert.cookie(name: "foo", domain: "www.example.com", "keep me")

    describe "by name, domain and path", ->
      before ->
        browser.deleteCookies()
        browser.setCookie(name: "foo", domain: "example.com", path: "/",    value: "keep me")
        browser.setCookie(name: "foo", domain: "example.com", path: "/bar", value: "delete me")

      it "should delete that cookie", ->
        browser.assert.cookie(name: "foo", domain: "example.com", path: "/bar", "delete me")
        assert browser.deleteCookie(name: "foo", domain: "example.com", path: "/bar")
        browser.assert.cookie(name: "foo", domain: "example.com", path: "/bar", "keep me")


  describe "deleteCookies", ->
    before ->
      browser.deleteCookies()
      browser.visit("http://example.com/")
      browser.setCookie("foo", "delete me")
      browser.setCookie("bar", "keep me")

    it "should delete all cookies", ->
      browser.deleteCookies()
      browser.assert.cookie("foo", null)
      browser.assert.cookie("bar", null)
      assert.equal browser.cookies.length, 0

    after ->
      browser.close()


  # -- Sending and receiving --

  before ->
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

    brains.get "/cookies/invalid", (req,res)->
      res.setHeader "Set-Cookie", "invalid"
      res.send "<html></html>"

    brains.get "/cookies/echo", (req,res)->
      cookies = ("#{k}=#{v}" for k,v of req.cookies).join("; ")
      res.send cookies

    brains.get "/cookies/empty", (req,res)->
      res.send ""


  describe "get cookies", ->

    before (done)->
      browser.deleteCookies()
      browser.visit("/cookies", done)

    describe "cookies", ->
      it "should have access to session cookie", ->
        browser.assert.cookie "_name", "value"
      it "should have access to persistent cookie", ->
        browser.assert.cookie "_expires1", "3s"
        browser.assert.cookie "_expires2", "5s"
      it "should not have access to expired cookies", ->
        browser.assert.cookie "_expires3", null
      it "should have access to cookies for the path /cookies", ->
        browser.assert.cookie "_path1", "yummy"
      it "should have access to cookies for paths which are ancestors of /cookies", ->
        browser.assert.cookie "_path4", "yummy"
      it "should not have access to other paths", ->
        browser.assert.cookie "_path2", null
        browser.assert.cookie "_path3", null
      it "should have access to .domain", ->
        browser.assert.cookie "_domain1", "here"
      it "should not have access to other domains", ->
        browser.assert.cookie "_domain2", null
        browser.assert.cookie "_domain3", null
      it "should access most specific cookie", ->
        browser.assert.cookie "_multiple", "specific"

    describe "invalid cookie", ->
      before (done)->
        browser.visit("/cookies/invalid", done)

      it "should not have the cookie", ->
        browser.assert.cookie "invalid", null

    describe "host in domain", ->
      it "should have access to host cookies", ->
        browser.assert.cookie "_domain1", "here"
      it "should not have access to other hosts' cookies", ->
        browser.assert.cookie "_domain2", null
        browser.assert.cookie "_domain3", null

    describe "document.cookie", ->
      before ->
        @cookie = browser.document.cookie

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
      browser.deleteCookies()
      browser.visit("/cookies", done)

    it "should be able to set domain cookies", ->
      browser.assert.cookie name: "_domain1", domain: "localhost", path: "/cookies", "here"


  describe "get cookies and redirect", ->

    before (done)->
      brains.get "/cookies/redirect", (req, res)->
        res.cookie "_expires4", "3s" #, expires: new Date(Date.now() + 3000), "Path": "/"
        res.redirect "/"

      browser.deleteCookies()
      browser.visit("/cookies/redirect", done)

    it "should have access to persistent cookie", ->
      browser.assert.cookie name: "_expires4", domain: "localhost", path: "/cookies/redirect", "3s"


  describe "duplicates", ->

    before (done)->
      brains.get "/cookies2", (req, res)->
        res.cookie "_dup", "two", path: "/"
        res.send ""
      brains.get "/cookies3", (req, res)->
        res.cookie "_dup", "three", path: "/"
        res.send ""

      browser.deleteCookies()
      browser.visit("/cookies2")
        .then ->
          browser.visit("/cookies3")
        .then(done, done)

    it "should retain last value", ->
      browser.assert.cookie "_dup", "three"
    it "should only retain last cookie", ->
      assert.equal browser.cookies.length, 1


  describe "send cookies", ->

    before (done)->
      browser.deleteCookies()
      browser.setCookie(domain: "localhost",                            name: "_name",                       value: "value")
      browser.setCookie(domain: "localhost",                            name: "_expires1",  "max-age": 3000,  value: "3s")
      browser.setCookie(domain: "localhost",                            name: "_expires2",  "max-age": 0,     value: "0s")
      browser.setCookie(domain: "localhost",    path: "/cookies",       name: "_path1",                       value: "here")
      browser.setCookie(domain: "localhost",    path: "/cookies/echo",  name: "_path2",                       value: "here")
      browser.setCookie(domain: "localhost",    path: "/jars",          name: "_path3",                       value: "there")
      browser.setCookie(domain: "localhost",    path: "/cookies/fido",  name: "_path4",                       value: "there")
      browser.setCookie(domain: "localhost",    path: "/",              name:"_path5",                        value: "here")
      browser.setCookie(domain: ".localhost",                           name: "_domain1",                     value: "here")
      browser.setCookie(domain: "not.localhost",                        name: "_domain2",                     value: "there")
      browser.setCookie(domain: "notlocalhost",                         name: "_domain3",                     value: "there")
      browser.visit "/cookies/echo", =>
        @cookies = cookiesFromHtml(browser)
        done()

    it "should send session cookie", ->
      assert.equal @cookies._name, "value"
    it "should pass persistent cookie to server", ->
      assert.equal @cookies._expires1, "3s"
    it "should not pass expired cookie to server", ->
      assert.equal @cookies._expires2, null
    it "should pass path cookies to server", ->
      assert.equal @cookies._path1, "here"
      assert.equal @cookies._path2, "here"
      assert.equal @cookies._path5, "here"
    it "should not pass unrelated path cookies to server", ->
      assert.equal @cookies._path3, null, "path3"
      assert.equal @cookies._path4, null, "path4"
      assert.equal @cookies._path6, null, "path5"
    it "should pass sub-domain cookies to server", ->
      assert.equal @cookies._domain1, "here"
    it "should not pass other domain cookies to server", ->
      assert.equal @cookies._domain2, null
      assert.equal @cookies._domain3, null


  describe "setting cookies from subdomains", ->
    before ->
      browser.deleteCookies()
      browser.cookies.update("foo=bar; domain=localhost")

    it "should be accessible", ->
      browser.assert.cookie domain: "localhost", name: "foo", "bar"
      browser.assert.cookie domain: "www.localhost", name: "foo", "bar"


  # -- Access from JS --

  describe "document.cookie", ->

    describe "setting cookie", ->
      before (done)->
        browser.visit("/cookies")
          .then ->
            browser.document.cookie = "foo=bar"
            return
          .then(done, done)

      it "should be available from document", ->
        assert ~browser.document.cookie.split("; ").indexOf("foo=bar")

      describe "on reload", ->
        before (done)->
          browser.visit("/cookies/echo", done)

        it "should send to server", ->
          cookies = cookiesFromHtml(browser)
          assert.equal cookies.foo, "bar"

      describe "different path", ->
        before (done)->
          browser.visit("/cookies")
            .then ->
              browser.document.cookie = "foo=bar"
              return
            .then(done, done)

        before (done)->
          browser.visit("/cookies/other")
            .then ->
              browser.document.cookie = "foo=qux" # more specific path, not visible to /cookies.echo
              return
            .fail(-> done())

        before (done)->
          browser.visit("/cookies/echo", done)

        it "should not be visible", ->
          cookies = cookiesFromHtml(browser)
          assert !cookies.bar
          assert.equal cookies.foo, "bar"


    describe "setting cookie with quotes", ->
      before (done)->
        browser.visit("/cookies/empty")
          .then ->
            browser.document.cookie = "foo=bar\"baz"
            return
          .then(done, done)

      it "should be available from document", ->
        browser.assert.cookie "foo", "bar\"baz"


    describe "setting cookie with semicolon", ->
      before (done)->
        browser.visit("/cookies/empty")
          .then ->
            browser.document.cookie = "foo=bar; baz"
            return
          .then(done, done)

      it "should be available from document", ->
        browser.assert.cookie "foo", "bar"


  after ->
    browser.destroy()
