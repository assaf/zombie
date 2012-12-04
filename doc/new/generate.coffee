#!/usr/bin/env coffee
{ execFile }  = require("child_process")
File          = require("fs")

console.log "Processing README.md ..."
layout = File.readFileSync("style/layout.html").toString()
execFile "markdown", ["README.md"], (error, stdout, stderr)->
  if error
    throw error

  console.log "Generating index.html ..."
  html = layout.replace("{content}", stdout)
  File.writeFileSync("index.html", html)

  console.log "Generating zombie.pdf ..."
  pdfOptions = [
    "--disable-javascript",
    "--outline",
    "--print-media-type",
    "--title", "Zombie.js",
    "--allow", "images",
    "--footer-center", "Page [page]",
    "index.html",
    "zombie.pdf"
  ]

  execFile "wkhtmltopdf", pdfOptions, (error, stdout, stderr)->
    if error
      throw error

    console.log "Generating zombie.mobi ..."
