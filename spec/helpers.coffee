require.paths.unshift __dirname + "/../node_modules"
fs = require("fs")
express = require("express")
zombie = require("../src/index")
debug = false # true


# When you run the vows command, it picks all the files in the spec directory
# and attempts to run their exports. If we wanted to export brains or zombie,
# Vows would try to run them, even though they're not test suites. So we hack
# around it by, instead of exporting, assigning them as instance variables on
# the Vows object. And for convenience we also include assert in there.
vows = require("vows")
vows.vows = vows
vows.assert = require("assert")

# Hack Vows console to figure out when Vows is done running tests and shut down
# the Web server.
vows.console = require("vows/console")
result = vows.console.result
vows.console.result = (results)->
  brains.close() if brains.active
  result.call vows.console, results

# An Express server we use to test the browser.
brains = express.createServer()
brains.use express.bodyDecoder()
brains.use express.cookieDecoder()


brains.get "/", (req, res)->
  res.send "<html><title>Tap, Tap</title></html>"
brains.get "/jquery.js", (req, res)->
  fs.readFile "#{__dirname}/.scripts/jquery.js", (err, data)-> res.send data
brains.get "/sammy.js", (req, res)->
  fs.readFile "#{__dirname}/.scripts/sammy.js", (err, data)->
    # Prevent sammy from polluting the output. Comment this if you need its
    # messages for debugging.
    data = data + ";window.Sammy.log = function() {}"
    res.send data
brains.ready = (callback)->
  if @active
    process.nextTick callback
  else
    @active = true
    brains.listen 3003, ->
      process.nextTick callback
  return # nothing

# Creates a new Vows context that will wait for the HTTP server to be ready,
# then create a new Browser, visit the specified page (url), run all the tests
# and shutdown the HTTP server.
#
# The second argument is the context with all its tests (and subcontexts). The
# topic passed to all tests is the browser window after loading the document.
# However, you can (and often need to) supply a ready function that will be
# called with err and window; the ready function can then call this.callback.
zombie.wants = (url, context)->
  topic = context.topic
  context.topic = ->
    new zombie.Browser().wants url, (err, browser)=>
      if topic
        try
          value = topic.call this, browser
          @callback null, value if value
        catch err
          @callback err
      else
        throw err if err
        browser.wait @callback
    return
  return context

zombie.Browser.prototype.wants = (url, options, callback)->
  brains.ready =>
    options.debug = debug
    @visit url, options, (err, browser)=>
      callback err, this if callback
  return


# Handle multipart/form-data so we can test file upload.
express.bodyDecoder.decode["multipart/form-data"] = (body)->
  # Find the boundary
  match = body.match(/^(--.*)\r\n(?:.|\n|\r)*\1--/m)
  if match && boundary = match[1]
    # Split body at boundary, ignore first (opening) and last (closing)
    # boundaries, and map the rest into name/value pairs.
    body.split("#{boundary}").slice(1,-1).reduce (parts, part)->
      # Each part consists of headers followed by the contents.
      split = part.trim().split("\r\n\r\n")
      heading = split[0]
      contents = split.slice(1).join("\r\n")
      # Now let's split the header into name/value pairs.
      headers = heading.split(/\r\n/).reduce (headers, line)->
        split = line.split(":")
        headers[split[0].toLowerCase()] = split.slice(1).join(":").trim()
        headers
      , {}

      contents = new Buffer(contents, "base64") if headers["content-transfer-encoding"] == "base64"
      contents.mime = headers["content-type"].split(/;/)[0]

      # We're looking for the content-disposition header, which has
      # form-data follows by name/value pairs, including the field name.
      if disp = headers["content-disposition"]
        pairs = disp.split(/;\s*/).slice(1).reduce (pairs, pair)->
          match = pair.match(/^(.*)="(.*)"$/)
          pairs[match[1]] = match[2]
          pairs
        , {}
        # From content disposition we can tell the field name, if it's a
        # file upload, also the file name. Content type is separate
        # header.
        contents = new String(contents) if typeof contents is "string"
        contents.filename = pairs.filename if pairs.filename
        parts[pairs.name] = contents if pairs.name
      parts
    , {}
  else
    {}


vows.zombie = zombie
vows.brains = brains
