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


  describe.only "deleteCookies", ->
    describe "no arguments", ->
      before ->
        browser.deleteCookies()
        browser.setCookie("foo", domain: "example.com", value: "delete me")
        browser.setCookie("bar", domain: "example.com", value: "delete me")

      it "should delete all cookies", ->
        assert.equal browser.cookies.length, 2
        assert.equal browser.deleteCookies(), 2
        assert.equal browser.cookies.length, 0

    describe "empty object", ->
      before ->
        browser.deleteCookies()
        browser.setCookie("foo", domain: "example.com", value: "delete me")
        browser.setCookie("bar", domain: "example.com", value: "delete me")

      it "should delete all cookies", ->
        assert.equal browser.cookies.length, 2
        assert.equal browser.deleteCookies({}), 2
        assert.equal browser.cookies.length, 0


    describe "by name", ->
      before ->
        browser.deleteCookies()
        browser.setCookie(name: "foo", domain: "example.com", value: "delete me")
        browser.setCookie(name: "bar", domain: "example.com", value: "keep me")

      it "should delete only named cookies", ->
        assert.equal browser.deleteCookies(name: "foo"), 1
        browser.assert.cookie(name: "foo", domain: "example.com", null)
        browser.assert.cookie(name: "bar", domain: "example.com", "keep me")


    describe "by name and domain", ->
      before ->
        browser.deleteCookies()
        browser.setCookie(name: "foo", domain: "www.example.com", value: "delete me")
        browser.setCookie(name: "foo", domain: ".example.com",    value: "delete me")

      it "should delete that cookie", ->
        browser.assert.cookie(name: "foo", domain: "www.example.com", "delete me")
        assert.equal browser.deleteCookies(name: "foo", domain: "www.example.com"), 2
        browser.assert.cookie(name: "foo", domain: "example.com", null)

    describe "by name, domain and path", ->
      before ->
        browser.deleteCookies()
        browser.setCookie(name: "foo", domain: "example.com", path: "/",        value: "keep me")
        browser.setCookie(name: "foo", domain: "example.com", path: "/bar",     value: "delete me")
        browser.setCookie(name: "foo", domain: "example.com", path: "/bar/baz", value: "delete me")

      it "should delete that cookie", ->
        console.dir browser.cookies
        assert.equal browser.deleteCookies(name: "foo", domain: "example.com", path: "/bar"), 2
        console.dir browser.cookies
        browser.assert.cookie(name: "foo", domain: "example.com", path: "/", "keep me")


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

    brains.get "/cookies/echo", (req,res)->
      cookies = ("#{k}=#{v}" for k,v of req.cookies).join("; ")
      res.send cookies

    brains.get "/cookies/empty", (req,res)->
      res.send ""


  describe "get cookies", ->

    before (done)->
      browser.clearCookies()
      browser.visit("/cookies", done)

    describe "cookies", ->
      it "should have access to session cookie", ->
        browser.assert.cookie "_name", "value"
      it "should have access to persistent cookie", ->
        browser.assert.cookie "_expires1", "3s"
        browser.assert.cookie "_expires2", "5s"
      it "should not have access to expired cookies", ->
        browser.assert.cookie "_expires3", undefined
      it "should have access to cookies for the path /cookies", ->
        browser.assert.cookie "_path1", "yummy"
      it "should have access to cookies for paths which are ancestors of /cookies", ->
        browser.assert.cookie "_path4", "yummy"
      it "should not have access to other paths", ->
        browser.assert.cookie "_path2", undefined
        browser.assert.cookie "_path3", undefined
      it "should have access to .domain", ->
        browser.assert.cookie "_domain1", "here"
      it "should not have access to other domains", ->
        browser.assert.cookie "_domain2", undefined
        browser.assert.cookie "_domain3", undefined
      it "should access most specific cookie", ->
        browser.assert.cookie "_multiple", "specific"


    describe "host in domain", ->
      it "should have access to host cookies", ->
        browser.assert.cookie "_domain1", "here"
      it "should not have access to other hosts' cookies", ->
        browser.assert.cookie "_domain2", undefined
        browser.assert.cookie "_domain3", undefined

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
      browser.clearCookies()
      browser.visit("/cookies", done)

    it "should be able to set domain cookies", ->
      cookies = browser.cookies("localhost", "/cookies")
      assert.equal cookies.get("_domain1"), "here"
      #browser.assert.cookie name: "_domain1", domain: "localhost", path: "/cookies", "here"


  describe "get cookies and redirect", ->

    before (done)->
      brains.get "/cookies/redirect", (req, res)->
        res.cookie "_expires4", "3s" #, expires: new Date(Date.now() + 3000), "Path": "/"
        res.redirect "/"

      browser.clearCookies()
      browser.visit("/cookies/redirect", done)

    it "should have access to persistent cookie", ->
      cookies = browser.cookies("localhost", "/cookies/redirect")
      assert.equal cookies.get("_expires4"), "3s"


  describe "duplicates", ->

    before (done)->
      brains.get "/cookies2", (req, res)->
        res.cookie "_dup", "two", path: "/"
        res.send ""
      brains.get "/cookies3", (req, res)->
        res.cookie "_dup", "three", path: "/"
        res.send ""

      browser.clearCookies()
      browser.visit("/cookies")
        .then ->
          browser.visit("/cookies2")
        .then ->
          browser.visit("/cookies3")
        .then(done, done)

    it "should retain last value", ->
      browser.assert.cookie "_dup", "three"
    it "should only retain last cookie", ->
      dups = browser.cookies().all().filter((c)-> c.key == "_dup")
      assert.equal dups.length, 1


  describe "send cookies", ->

    before (done)->
      browser.clearCookies()
      browser.cookies("localhost"                   ).set("_name",      "value")
      browser.cookies("localhost"                   ).set("_expires1",  "3s",     "max-age": 3000)
      browser.cookies("localhost"                   ).set("_expires2",  "0s",     "max-age": 0)
      browser.cookies("localhost", "/cookies"       ).set("_path1",     "here")
      browser.cookies("localhost", "/cookies/echo"  ).set("_path2",     "here")
      browser.cookies("localhost", "/jars"          ).set("_path3",     "there",  "path": "/jars")
      browser.cookies("localhost", "/cookies/fido"  ).set("_path4",     "there",  "path": "/cookies/fido")
      browser.cookies("localhost", "/"              ).set("_path5",     "here",   "path": "/cookies")
      browser.cookies(".localhost"                  ).set("_domain1",   "here")
      browser.cookies("not.localhost"               ).set("_domain2",   "there")
      browser.cookies("notlocalhost"                ).set("_domain3",   "there")
      browser.visit "/cookies/echo", =>
        @cookies = cookiesFromHtml(browser)
        done()

    it "should send session cookie", ->
      assert.equal @cookies._name, "value"
    it "should pass persistent cookie to server", ->
      assert.equal @cookies._expires1, "3s"
    it "should not pass expired cookie to server", ->
      assert.equal @cookie._expires2, undefined
    it "should pass path cookies to server", ->
      assert.equal @cookies._path1, "here"
      assert.equal @cookies._path2, "here"
      assert.equal @cookies._path5, "here"
    it "should not pass unrelated path cookies to server", ->
      assert.equal @cookies._path3, undefined, "path3"
      assert.equal @cookies._path4, undefined, "path4"
      assert.equal @cookies._path6, undefined, "path5"
    it "should pass sub-domain cookies to server", ->
      assert.equal @cookies._domain1, "here"
    it "should not pass other domain cookies to server", ->
      assert.equal @cookies._domain2, undefined
      assert.equal @cookies._domain3, undefined


  describe "setting cookies from subdomains", ->
    before ->
      browser.clearCookies()
      browser.cookies("www.localhost").update("foo=bar; domain=.localhost")

    it "should be accessible", ->
      assert.equal "bar", browser.cookies("localhost").get("foo")
      assert.equal "bar", browser.cookies("www.localhost").get("foo")


  describe "setting Cookie header", ->
    before ->
      @header = { cookie: "" }
      browser.clearCookies()
      browser.cookies().update("foo=bar;")
      browser.cookies().addHeader(@header)

    it "should send V0 header", ->
      assert.equal @header.cookie, "foo=bar"


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
            .finally(done)

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
