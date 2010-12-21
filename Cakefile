fs            = require("fs")
path          = require("path")
{spawn, exec} = require("child_process")
markdown      = require("node-markdown").Markdown

# ANSI Terminal Colors.
bold  = "\033[0;1m"
red   = "\033[0;31m"
green = "\033[0;32m"
reset = "\033[0m"

# Log a message with a color.
log = (message, color, explanation) ->
  console.log color + message + reset + ' ' + (explanation or '')

task "clean", "Remove temporary files and such", ->
  exec "rm -rf html"


# Setup
# -----

# Setup development dependencies, not part of runtime dependencies.
task "setup", "Install development dependencies", ->
  log "Need Vows and Express to run test suite, installing ...", green
  exec "npm install \"vows@>=0.\"5"
  exec "npm install \"express@>=1.0\""
  log "Need Ronn and Docco to generate documentation, installing ...", green
  exec "npm install \"ronn@>=0.3\""
  exec "npm install \"docco@>=0.3\""
  log "Need runtime dependencies, installing ...", green
  fs.readFile "package.json", "utf8", (err, package)->
    for name, version of JSON.parse(package).dependencies
      exec "npm install \"#{name}@#{version}\""


# Documentation
# -------------

# Markdown to HTML.
toHTML = (source, callback)->
  target = "html/#{path.basename(source, ".md").toLowerCase()}.html"
  title = path.basename(source, ".md").replace("_", " ")
  fs.mkdir "html", 0777, ->
    fs.readFile "doc/_layout.html", "utf8", (err, layout)->
      fs.readFile source, "utf8", (err, text)->
        throw err if err
        log "Creating #{target} ...", green
        exec "ronn --html #{source}", (err, stdout, stderr)->
          throw err if err
          title = stdout.match(/<h1>(.*)<\/h1>/)[1]
          html = layout.replace("{{body}}", stdout).replace(/{{title}}/g, title).replace(/<h1>.*<\/h1>/, "")
          fs.writeFile target, html, "utf8"
          callback target if callback

task "doc:source", ->
  log "Documenting source files ...", green
  exec "docco lib/**/*.coffee", (err) ->
    throw err if err
    log "Copying to html/source ...", green
    exec "mkdir -p html && cp -rf docs/ html/source && rm -rf docs"

task "doc:pages", ->
  toHTML "README.md", ->
    exec "mv html/readme.html html/index.html"
    "index.html"
  toHTML "TODO.md"
  exec "cp -f doc/*.css html/"

task "doc", "Generate documentation", ->
  invoke "doc:pages"
  invoke "doc:source"


# Testing
# -------

task "test", "Run all tests", ->
  exec "vows --spec", (err, stdout, stderr)->
    log stdout, green
    log stderr, red


# Publishing
# ----------

task "doc:publish", ->
  log "Uploading documentation ...", green
  exec "rsync -cr --del --progress html/ labnotes.org:/var/www/zombie/"

task "publish", "Publish new version (Git, NPM, site)", ->
  fs.readFile "package.json", "utf8", (err, package)->
    version = JSON.parse(package).version
    log "Tagging v#{version} ...", green
    exec "git tag v#{version}", ->
      exec "git push"

  log "Publishing in NPM ...", green
  invoke "clean" # Need to rid of all the crap, or it gets included
  invoke "npm publish"

  invoke "doc:publish"
