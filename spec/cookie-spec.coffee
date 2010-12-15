require("./helpers")
{ vows: vows, assert: assert, zombie: zombie, brains: brains } = require("vows")

brains.get "/cookies", (req, res)->
  res.cookie "_name", "value"
  res.cookie "_expires1", "3s", "Expires": new Date(Date.now() + 3000)
  res.cookie "_expires2", "5s", "Max-Age": 5000
  res.cookie "_expires3", "0s", "Expires": new Date()
  res.cookie "_expires4", "0s", "Max-Age": 0
  res.cookie "_path1", "yummy", "Path": "/cookies"
  res.cookie "_path2", "yummy", "Path": "/cookies/sub"
  res.cookie "_path3", "wrong", "Path": "/cookies/wrong"
  res.cookie "_domain1", "here", "Domain": ".localhost"
  res.cookie "_domain2", "not here", "Domain": "not.localhost"
  res.cookie "_domain3", "wrong", "Domain": "notlocalhost"
  res.send "<html></html>"
brains.get "/cookies/echo", (req,res)->
  res.send "<html>#{req.headers["cookie"]}</html>"

vows.describe("Cookies").addBatch(
  "get cookies":
    zombie.wants "http://localhost:3003/cookies"
     "should have access to session cookie": (browser)-> assert.equal browser.cookies.get("_name"), "value"
     "should have access to persistent cookie": (browser)->
       assert.equal browser.cookies.get("_expires1"), "3s"
       assert.equal browser.cookies.get("_expires2"), "5s"
     "should not have access to expired cookies": (browser)->
       assert.isUndefined browser.cookies.get("_expires3")
       assert.isUndefined browser.cookies.get("_expires4")
     "should have access to path cookies": (browser)-> assert.equal browser.cookies.get("_path1"), "yummy"
     "should not have access to other paths": (browser)->
       assert.isUndefined browser.cookies.get("_path2")
       assert.isUndefined browser.cookies.get("_path2")
     "should not have access to .domain": (browser)-> assert.equal browser.cookies.get("_domain1"), "here"
     "should not have access to other domains": (browser)->
       assert.isUndefined browser.cookies.get("_domain2")
       assert.isUndefined browser.cookies.get("_domain3")
     "document.cookie":
       topic: (browser)->
         browser.document.cookie
       "should return name/value pairs": (cookie)-> assert.match cookie, /^(\w+=\w+; )+\w+=\w+$/
       "pairs":
         topic: (serialized)->
           pairs = serialized.split("; ").reduce (map, pair)->
             [name, value] = pair.split("=")
             map[name] = value
             map
           , {}
         "should include only visibile cookies": (pairs)->
           keys = (key for key, value of pairs).sort()
           assert.deepEqual keys, "_domain1 _expires1 _expires2 _name _path1".split(" ")
         "should match name to value": (pairs)->
          assert.equal pairs._name, "value"
          assert.equal pairs._path1, "yummy"

  "send cookies":
    topic: ->
      browser = new zombie.Browser()
      browser.cookies.set "_name", "value", domain: "localhost"
      browser.cookies.set "_expires1", "3s", domain: "localhost", "max-age": 3000
      browser.cookies.set "_expires2", "0s", domain: "localhost", "max-age": 0
      browser.cookies.set "_path1", "here", domain: "localhost", path: "/cookies"
      browser.cookies.set "_path2", "here", domain: "localhost", path: "/cookies/echo"
      browser.cookies.set "_path3", "there", domain: "localhost", path: "/jars"
      browser.cookies.set "_path4", "there", domain: "localhost", path: "/cookies/echo/"
      browser.cookies.set "_domain1", "here", domain: ".localhost"
      browser.cookies.set "_domain2", "there", domain: "not.localhost"
      browser.cookies.set "_domain3", "there", domain: "notlocalhost"
      browser.wants "http://localhost:3003/cookies/echo", =>
        cookies = browser.text("html").split(/;\s*/).reduce (all, cookie)->
          [name, value] = cookie.split("=")
          all[name] = value.replace(/^"(.*)"$/, "$1")
          all
        , {}
        @callback null, cookies
    "should send session cookie": (cookies)-> assert.equal cookies._name, "value"
    "should pass persistent cookie to server": (cookies)-> assert.equal cookies._expires1, "3s"
    "should not pass expired cookie to server": (cookies)-> assert.isUndefined cookies._expires2
    "should pass path cookies to server": (cookies)->
      assert.equal cookies._path1, "here"
      assert.equal cookies._path2, "here"
    "should not pass unrelated path cookies to server": (cookies)->
      assert.isUndefined cookies._path3
      assert.isUndefined cookies._path4
    "should pass sub-domain cookies to server": (cookies)-> assert.equal cookies._domain1, "here"
    "should not pass other domain cookies to server": (cookies)->
      assert.isUndefined cookies._domain2
      assert.isUndefined cookies._domain3

).export(module)
