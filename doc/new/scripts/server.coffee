#!/usr/bin/env coffee
Express       = require("express")
{ execFile }  = require("child_process")
File          = require("fs")

server = Express()

server.get "/", (req, res)->
  layout = File.readFileSync("#{__dirname}/../style/layout.html").toString()
  execFile "markdown", ["#{__dirname}/../README.md"], {}, (error, stdout, stderr)->
    if error
      res.send(500, error.message)
    else
      html = layout.replace("{content}", stdout)
      res.send(html)

server.get "/*", (req, res)->
  try
    File.createReadStream("#{__dirname}/../#{req.params[0]}")
      .on "error", (error)->
        res.send(404, error.message)
      .pipe(res)
  catch error
    res.send(500, error.message)

server.listen 3000, ->
  console.log "open http://localhost:3000/"
