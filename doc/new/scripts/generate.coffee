#!/usr/bin/env coffee
#
# Generates Web page (index.html), PDF (zombie.pdf) and Kindle Mobile
# (zombie.mobi).
#
# To use:
#
#   ./scripts/generate
#   open index.html
#   open zombie.pdf
#   open zombie.mobi
#
# You'll need Markdown to generate all three documents:
#
#   brew install markdown
#
# WkHTMLtoPDF to generate the PDF:
#
#   brew install wkhtmltopdf
#
# And kindlegen available for download from Amazon.


{ execFile }  = require("child_process")
File          = require("fs")


console.log "Generating index.html ..."
layout = File.readFileSync("#{__dirname}/../style/layout.html").toString()
execFile "markdown", ["#{__dirname}/../README.md"], (error, stdout, stderr)->
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
  File.writeFileSync("#{__dirname}/../index.html", html)

  console.log "Generating zombie.pdf ..."
  pdfOptions = [
    "--disable-javascript",
    "--outline",
    "--print-media-type",
    "--title", "Zombie.js",
    "--allow", "images",
    "--footer-center", "Page [page]",
    "#{__dirname}/../index.html",
    "#{__dirname}/../zombie.pdf"
  ]
  execFile "wkhtmltopdf", pdfOptions, (error, stdout, stderr)->
    if error
      console.error("Note: if you haven't already, brew install wkhtmltopdf")
      console.error(error.message)

    console.log "Generating zombie.mobi ..."
    kindleOptions = [
      "-c2"
      "#{__dirname}/../index.html",
      "-o", "zombie.mobi"
    ]
    execFile "kindlegen", kindleOptions, (error, stdout, stderr)->
      console.log(stdout)

      console.log "Done"
      process.exit(0)
