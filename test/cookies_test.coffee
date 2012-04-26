{ Vows, assert, brains, Browser } = require("./helpers")


describe "Cookies", ->

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
      res.cookie "_http_only","value",    httpOnly: true
      res.send "<html></html>"

    brains.get "/cookies/echo", (req,res)->
      cookies = ("#{k}=#{v}" for k,v of req.cookies).join("; ")
      res.send "<html>#{cookies}</html>"

    brains.get "/cookies_redirect", (req, res)->
      res.cookie "_expires4", "3s",       expires: new Date(Date.now() + 3000), "Path": "/"
      res.redirect "/"

    brains.get "/cookies/empty", (req,res)->
      res.send "<html></html>"

    brains.ready done


  describe "get cookies", ->
    browser = new Browser()

    before (done)->
      browser.visit "http://localhost:3003/cookies", done

      describe "cookies", ->
        cookies = null
        before ->
          cookies = browser.cookies("localhost", "/cookies")

        it "should have access to session cookie", ->
          assert.equal cookies.get("_name"), "value"
        it "should have access to persistent cookie", ->
          assert.equal cookies.get("_expires1"), "3s"
          assert.equal cookies.get("_expires2"), "5s"
        it "should not have access to expired cookies", ->
          assert cookies.get("_expires3") == undefined
        it "should have access to cookies for the path /cookies", ->
          assert.equal cookies.get("_path1"), "yummy"
        it "should have access to cookies for paths which are ancestors of /cookies", ->
          assert.equal cookies.get("_path4"), "yummy"
        it "should not have access to other paths", ->
          assert cookies.get("_path2") == undefined
          assert cookies.get("_path3") == undefined
        it "should have access to .domain", ->
          assert.equal cookies.get("_domain1"), "here"
        it "should not have access to other domains", ->
          assert cookies.get("_domain2") == undefined
          assert cookies.get("_domain3") == undefined

      describe "host in domain", ->
        cookies = null
        before ->
          cookies = browser.cookies("host.localhost")

        it "should not have access to domain cookies", ->
          assert cookies.get("_name") == undefined
        it "should have access to .host cookies", ->
          assert.equal cookies.get("_domain1"), "here"
        it "should not have access to other hosts' cookies", ->
          assert cookies.get("_domain2") == undefined
          assert cookies.get("_domain3") == undefined

      describe "document.cookie", ->
        cookie = null
        before ->
          cookie = browser.document.cookie

        it "should return name/value pairs", ->
          assert /^(\w+=\w+; )+\w+=\w+$/.test(cookie)

        describe "pairs", ->
          pairs = null
          before ->
            pairs = cookie.split("; ").reduce (map, pair)->
              [name, value] = pair.split("=")
              map[name] = value
              map
            , {}

          it "should include only visible cookies", ->
            keys = (key for key, value of pairs).sort()
            assert.equal keys, "_domain1 _expires1 _expires2 _name _path1 _path4".split(" ")
          it "should match name to value": (pairs)->
           assert.equal pairs._name, "value"
           assert.equal pairs._path1, "yummy"
          it "should not include httpOnly cookies", ->
            for key, value of pairs
              assert key != "_http_only"


  describe "host", ->
    cookies = null

    before (done)->
      browser = new Browser()
      browser.visit "http://host.localhost:3003/cookies", ->
        cookies = browser.cookies("localhost", "/cookies")
        done()

    it "should be able to set domain cookies", ->
      assert.equal cookies.get("_domain1"), "here"


  describe "get cookies and redirect", ->
    cookies = null

    before (done)->
      browser = new Browser()
      browser.visit "http://localhost:3003/cookies_redirect", ->
        cookies = browser.cookies("localhost", "/")
        done()

    it "should have access to persistent cookie", ->
      assert.equal cookies.get("_expires4"), "3s"


  describe "send cookies", ->
    cookies = null

    before (done)->
      browser = new Browser()
      browser.cookies("localhost"                   ).set "_name",      "value"
      browser.cookies("localhost"                   ).set "_expires1",  "3s",     "max-age": 3000
      browser.cookies("localhost"                   ).set "_expires2",  "0s",     "max-age": 0
      browser.cookies("localhost", "/cookies"       ).set "_path1",     "here"
      browser.cookies("localhost", "/cookies/echo"  ).set "_path2",     "here"
      browser.cookies("localhost", "/jars"          ).set "_path3",     "there",  "path": "/jars"
      browser.cookies("localhost", "/cookies/fido"  ).set "_path4",     "there",  "path": "/cookies/fido"
      browser.cookies("localhost", "/jars"          ).set "_path5",     "here",   "path": "/cookies"
      browser.cookies("localhost", "/jars"          ).set "_path6",     "here"
      browser.cookies("localhost", "/jars/"         ).set "_path7",     "there"
      browser.cookies(".localhost"                  ).set "_domain1",   "here"
      browser.cookies("not.localhost"               ).set "_domain2",   "there"
      browser.cookies("notlocalhost"                ).set "_domain3",   "there"
      browser.visit "http://localhost:3003/cookies/echo", ->
        cookies = browser.text("html").split(/;\s*/).reduce (all, cookie)->
          [name, value] = cookie.split("=")
          all[name] = value.replace(/^"(.*)"$/, "$1")
          all
        , {}
        done()

    it "should send session cookie", ->
      assert.equal cookies._name, "value"
    it "should pass persistent cookie to server", ->
      assert.equal cookies._expires1, "3s"
    it "should not pass expired cookie to server", ->
      assert cookies._expires2 == undefined
    it "should pass path cookies to server", ->
      assert.equal cookies._path1, "here"
      assert.equal cookies._path2, "here"
    it "should pass cookies that specified a different path when they were assigned", ->
      assert.equal cookies._path5, "here"
    it "should pass cookies that didn't specify a path when they were assigned", ->
      assert.equal cookies._path6, "here"
    it "should not pass unrelated path cookies to server", ->
      assert cookies._path3 == undefined
      assert cookies._path4 == undefined
      assert cookies._path7 == undefined
    it "should pass sub-domain cookies to server", ->
      assert.equal cookies._domain1, "here"
    it "should not pass other domain cookies to server", ->
      assert cookies._domain2 == undefined
      assert cookies._domain3 == undefined


  describe "setting cookies from subdomains", ->
    browser = new Browser()
    before ->
      browser.cookies("www.localhost").update("foo=bar; domain=.localhost")
      
    it "should be accessible", ->
      assert.equal "bar", browser.cookies("localhost").get("foo")
      assert.equal "bar", browser.cookies("www.localhost").get("foo")


  describe "setting Cookie header", ->
    header = { cookie: "" }
    before ->
      browser = new Browser()
      browser.cookies().update("foo=bar;")
      browser.cookies().addHeader header
      
    it "should send V0 header", ->
      assert.equal header.cookie, "foo=bar"


  describe "document.cookie", ->
    browser = new Browser()

    describe "setting cookie", ->
      before (done)->
        browser.visit "http://localhost:3003/cookies/empty", ->
          browser.document.cookie = "foo=bar"
          done()

      it "should be available from document", ->
        assert.equal browser.document.cookie, "foo=bar"

      describe "send request", ->
        cookies = null

        before (done)->
          browser.visit "http://localhost:3003/cookies/echo", ->
            cookies = browser.text("html").split(/;\s*/).reduce (all, cookie)->
              [name, value] = cookie.split("=")
              all[name] = value.replace(/^"(.*)"$/, "$1")
              all
            , {}
            done()

        it "should send to server", ->
          assert.equal cookies.foo, "bar"

    describe "setting cookie with quotes", ->
      before (done)->
        browser.visit "http://localhost:3003/cookies/empty", ->
          browser.document.cookie = "foo=bar\"baz"
          done()

      it "should be available from document": (browser)->
        assert.equal browser.cookies().get("foo"), "bar\"baz"

    describe "setting cookie with semicolon", ->
      before (done)->
        browser.visit "http://localhost:3003/cookies/empty", ->
          browser.document.cookie = "foo=bar; baz"
          done()

      it "should be available from document", ->
        assert.equal browser.cookies().get("foo"), "bar"

