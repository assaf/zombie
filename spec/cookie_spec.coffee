{ Vows, assert, brains, Browser } = require("./helpers")


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


Vows.describe("Cookies").addBatch(

  "get cookies":
    Browser.wants "http://localhost:3003/cookies"
      "cookies":
        topic: (browser)->
          browser.cookies("localhost", "/cookies")
        "should have access to session cookie": (cookies)->
          assert.equal cookies.get("_name"), "value"
        "should have access to persistent cookie": (cookies)->
          assert.equal cookies.get("_expires1"), "3s"
          assert.equal cookies.get("_expires2"), "5s"
        "should not have access to expired cookies": (cookies)->
          assert.isUndefined cookies.get("_expires3")
        "should have access to cookies for the path /cookies": (cookies)->
          assert.equal cookies.get("_path1"), "yummy"
        "should have access to cookies for paths which are ancestors of /cookies": (cookies)->
          assert.equal cookies.get("_path4"), "yummy"
        "should not have access to other paths": (cookies)->
          assert.isUndefined cookies.get("_path2")
          assert.isUndefined cookies.get("_path3")
        "should have access to .domain": (cookies)->
          assert.equal cookies.get("_domain1"), "here"
        "should not have access to other domains": (cookies)->
          assert.isUndefined cookies.get("_domain2")
          assert.isUndefined cookies.get("_domain3")

      "host in domain":
        topic: (browser)->
          browser.cookies("host.localhost")
        "should not have access to domain cookies": (cookies)->
          assert.isUndefined cookies.get("_name")
        "should have access to .host cookies": (cookies)->
          assert.equal cookies.get("_domain1"), "here"
        "should not have access to other hosts' cookies": (cookies)->
          assert.isUndefined cookies.get("_domain2")
          assert.isUndefined cookies.get("_domain3")

      "document.cookie":
        topic: (browser)->
          browser.document.cookie
        "should return name/value pairs": (cookie)->
          assert.match cookie, /^(\w+=\w+; )+\w+=\w+$/
        "pairs":
          topic: (serialized)->
            pairs = serialized.split("; ").reduce (map, pair)->
              [name, value] = pair.split("=")
              map[name] = value
              map
            , {}
          "should include only visible cookies": (pairs)->
            keys = (key for key, value of pairs).sort()
            assert.deepEqual keys, "_domain1 _expires1 _expires2 _name _path1 _path4".split(" ")
          "should match name to value": (pairs)->
           assert.equal pairs._name, "value"
           assert.equal pairs._path1, "yummy"
          "should not include httpOnly cookies": (pairs)->
            for key, value of pairs
              assert.notEqual key, "_http_only"


  "host":
    Browser.wants "http://host.localhost:3003/cookies"
      "cookies":
        topic: (browser)->
          browser.cookies("localhost", "/cookies")
        "should be able to set domain cookies": (cookies)->
          assert.equal cookies.get("_domain1"), "here"


  "get cookies and redirect":
    Browser.wants "http://localhost:3003/cookies_redirect"
      "cookies":
        topic: (browser)->
          browser.cookies("localhost", "/")
        "should have access to persistent cookie": (cookies)->
          assert.equal cookies.get("_expires4"), "3s"


  "send cookies":
    topic: ->
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
      browser.wants "http://localhost:3003/cookies/echo", =>
        cookies = browser.text("html").split(/;\s*/).reduce (all, cookie)->
          [name, value] = cookie.split("=")
          all[name] = value.replace(/^"(.*)"$/, "$1")
          all
        , {}
        @callback null, cookies

    "should send session cookie": (cookies)->
      assert.equal cookies._name, "value"
    "should pass persistent cookie to server": (cookies)->
      assert.equal cookies._expires1, "3s"
    "should not pass expired cookie to server": (cookies)->
      assert.isUndefined cookies._expires2
    "should pass path cookies to server": (cookies)->
      assert.equal cookies._path1, "here"
      assert.equal cookies._path2, "here"
    "should pass cookies that specified a different path when they were assigned": (cookies)->
      assert.equal cookies._path5, "here"
    "should pass cookies that didn't specify a path when they were assigned": (cookies)->
      assert.equal cookies._path6, "here"
    "should not pass unrelated path cookies to server": (cookies)->
      assert.isUndefined cookies._path3
      assert.isUndefined cookies._path4
      assert.isUndefined cookies._path7
    "should pass sub-domain cookies to server": (cookies)->
      assert.equal cookies._domain1, "here"
    "should not pass other domain cookies to server": (cookies)->
      assert.isUndefined cookies._domain2
      assert.isUndefined cookies._domain3


  "setting cookies from subdomains":
    topic: ->
      browser = new Browser()
      browser.cookies("www.localhost").update("foo=bar; domain=.localhost")
      @callback null, browser
    "should be accessible": (browser)->
      assert.equal "bar", browser.cookies("localhost").get("foo")
      assert.equal "bar", browser.cookies("www.localhost").get("foo")


  "setting Cookie header":
    topic: ->
      browser = new Browser()
      header = { cookie: "" }
      browser.cookies().update("foo=bar;")
      browser.cookies().addHeader header
      header
    "should send V0 header": (header)->
      assert.equal header.cookie, "foo=bar"


  "document.cookie":
    topic: ->
      browser = new Browser()
      @callback null, browser
    "setting cookie":
      topic: (browser)->
        browser.wants "http://localhost:3003/cookies/empty", =>
          browser.document.cookie = "foo=bar"
          @callback null, browser
      "should be available from document": (browser)->
        assert.equal browser.document.cookie, "foo=bar"
      "send request":
        topic: (browser)->
          browser.wants "http://localhost:3003/cookies/echo", =>
            cookies = browser.text("html").split(/;\s*/).reduce (all, cookie)->
              [name, value] = cookie.split("=")
              all[name] = value.replace(/^"(.*)"$/, "$1")
              all
            , {}
            @callback null, cookies
        "should send to server": (cookies)->
          assert.equal cookies.foo, "bar"

    "setting cookie with quotes":
      topic: (browser)->
        browser.wants "http://localhost:3003/cookies/empty", =>
          browser.document.cookie = "foo=bar\"baz"
          @callback null, browser
      "should be available from document": (browser)->
        assert.equal browser.cookies().get("foo"), "bar\"baz"

    "setting cookie with semicolon":
      topic: (browser)->
        browser.wants "http://localhost:3003/cookies/empty", =>
          browser.document.cookie = "foo=bar; baz"
          @callback null, browser
      "should be available from document": (browser)->
        assert.equal browser.cookies().get("foo"), "bar"


).export(module)
