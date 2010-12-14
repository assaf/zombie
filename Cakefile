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
  exec "docco lib/**/*.coffee && rm -rf html && cp -r docs html && rm -rf docs", (err) ->
    throw err if err

task "test", "Run all tests", -> exec "vows"

task "clean", "Remove temporary files and such", ->
  exec "rm -rf html"
