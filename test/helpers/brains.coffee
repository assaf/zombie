Express = require("express")
File    = require("fs")
Path    = require("path")


# An express server we use to test the browser.
brains = Express.createServer()
brains.use Express.bodyParser()
brains.use Express.cookieParser()


brains.get "/", (req, res)->
  res.send "<html><title>Tap, Tap</title></html>"

# Prevent sammy from polluting the output. Comment this if you need its
# messages for debugging.
brains.get "/sammy.js", (req, res)->
  File.readFile "#{__dirname}/../scripts/sammy.js", (err, data)->
    #    unless process.env.DEBUG
    #  data = data + ";window.Sammy.log = function() {}"
    res.send data

brains.get "/jquery.js", (req, res)->
  res.redirect "/jquery-1.7.1.js"
brains.get "/jquery-:version.js", (req, res)->
  version = req.params.version
  File.readFile "#{__dirname}/../scripts/jquery-#{version}.js", (err, data)->
    res.send data
brains.get "/scripts/require.js", (req, res)->
  file = Path.resolve(require.resolve("requirejs"), "../../require.js")
  File.readFile file, (err, data)->
    res.send data
brains.get "/scripts/*", (req, res)->
  File.readFile "#{__dirname}/../scripts/#{req.params}", (err, data)->
    res.send data


active = false
brains.ready = (callback)->
  if active
    process.nextTick callback
  else
    brains.listen 3003, ->
      active = true
      callback()


module.exports = brains
