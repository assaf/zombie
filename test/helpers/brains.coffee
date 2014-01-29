express = require("express")
File    = require("fs")
Path    = require("path")


# An Express server we use to test the browser.
brains = express()
brains.use(express.bodyParser())
brains.use(express.cookieParser())


brains.get "/", (req, res)->
  res.send """
    <html>
      <head>
        <title>Tap, Tap</title>
      </head>
      <body>
      </body>
    </html>
  """

# Prevent sammy from polluting the output. Comment this if you need its
# messages for debugging.
brains.get "/sammy.js", (req, res)->
  File.readFile "#{__dirname}/../scripts/sammy.js", (err, data)->
    #    unless process.env.DEBUG
    #  data = data + ";window.Sammy.log = function() {}"
    res.send data

brains.get "/jquery.js", (req, res)->
  res.redirect "/jquery-2.0.3.js"
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
  ready = (callback)->
    if active
      process.nextTick callback
    else
      brains.listen 3003, ->
        active = true
        callback()
  if callback
    ready(callback)
  else
    return ready


module.exports = brains
