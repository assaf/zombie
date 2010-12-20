fs            = require("fs")
path          = require("path")
{spawn, exec} = require("child_process")

# ANSI Terminal Colors.
bold  = "\033[0;1m"
red   = "\033[0;31m"
green = "\033[0;32m"
reset = "\033[0m"

# Log a message with a color.
log = (message, color, explanation) ->
  console.log color + message + reset + ' ' + (explanation or '')

task "doc:source", "Builds source documentation", ->
  log "Documenting source files", green
  exec "docco lib/**/*.coffee && mv -f docs/* html/ && rm -rf docs", (err) -> throw err if err

task "doc:readme", "Build README file", ->
  markdown = require("node-markdown").Markdown
  fs.mkdir "html", 0777, ->
    fs.readFile "README.md", "utf8", (err, text)->
      log "Creating html/index.html", green
      exec "ronn --html README.md", (err, stdout, stderr)->
        throw err if err
        fs.writeFile "html/index.html", stdout, "utf8"

task "doc", "Generate documentation", ->
  invoke "doc:readme"
  invoke "doc:source"

task "test", "Run all tests", ->
  exec "vows --spec", (err, stdout, stderr)->
    console.log stdout
    console.error stderr

task "clean", "Remove temporary files and such", ->
  exec "rm -rf html"
