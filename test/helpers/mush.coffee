express = require("express")
File    = require("fs")
Path    = require("path")

# Another Express server for serving up content from a foriegn domain... We're using this to test CORS.
mush = express()
mush.use(express.bodyParser())
mush.use(express.cookieParser())


mush.get "/", (req, res)->
  res.send """
    <html>
      <head>
        <title>Tap, Tap, Tap</title>
      </head>
      <body>
      </body>
    </html>
  """


mush.get "/jquery.js", (req, res)->
  res.redirect "/jquery-1.7.1.js"
mush.get "/jquery-:version.js", (req, res)->
  version = req.params.version
  File.readFile "#{__dirname}/../scripts/jquery-#{version}.js", (err, data)->
    res.send data
mush.get "/scripts/require.js", (req, res)->
  file = Path.resolve(require.resolve("requirejs"), "../../require.js")
  File.readFile file, (err, data)->
    res.send data
mush.get "/scripts/*", (req, res)->
  File.readFile "#{__dirname}/../scripts/#{req.params}", (err, data)->
    res.send data

active = false
mush.ready = (callback)->
  if active
    mush.nextTick callback
  else
    mush.listen 3010, ->
      active = true
      callback()


module.exports = mush
