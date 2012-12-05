#!/usr/bin/env coffee
{ execFile }  = require("child_process")
File          = require("fs")


console.log "Generating index.html ..."
layout = File.readFileSync("style/layout.html").toString()
execFile "markdown", ["README.md"], (error, stdout, stderr)->
  if error
    console.error("Note: if you haven't already, brew install markdown")
    console.error(error.message)
    process.exit(1)

  # Add IDs for all headers so they can be references
  addIDToHeader = (match, level, textContent)->
    id = textContent.replace(/\s+/, "_").toLowerCase()
    return "<h#{level} id=\"#{id}\">#{textContent}</h#{level}>"
  content = stdout.replace(/<h([1-3])>(.*)<\/h[1-3]>/g, addIDToHeader)

  html = layout.replace("{content}", content)
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
      console.error("Note: if you haven't already, brew install wkhtmltopdf")
      console.error(error.message)

    console.log "Generating zombie.mobi ..."
    kindleOptions = [
      "-c2"
      "index.html",
      "-o", "zombie.mobi"
    ]
    execFile "kindlegen", kindleOptions, (error, stdout, stderr)->
      console.log(stdout)

      console.log "Done"
      process.exit(0)
