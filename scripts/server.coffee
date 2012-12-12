#!/usr/bin/env coffee
#
# Simple Web server to serve HTML documentation.
#
# To use:
#
#   ./scripts/server &
#   open http://localhost:3000
#
# This server is necessary to test some behavior that only works when viewing
# the documentation over HTTP and fails when opening a file.  Specifically, it
# seems JavaScript cannot access external stylesheets when HTML is loaded from
# the file system.


Express       = require("express")
{ execFile }  = require("child_process")
File          = require("fs")
Path          = require("path")


DOC_DIR   = Path.resolve("#{__dirname}/../doc/new")


server = Express()

server.get "/", (req, res)->
  layout = File.readFileSync("#{DOC_DIR}/layout.html").toString()
  execFile "markdown", ["#{DOC_DIR}/README.md"], {}, (error, stdout, stderr)->
    if error
      res.send(500, error.message)
    else
      html = layout.replace("{content}", stdout)
      res.send(html)

server.get "/*", (req, res)->
  try
    File.createReadStream("#{DOC_DIR}/#{req.params[0]}")
      .on "error", (error)->
        res.send(404, error.message)
      .pipe(res)
  catch error
    res.send(500, error.message)

server.listen 3000, ->
  console.log "open http://localhost:3000/"
