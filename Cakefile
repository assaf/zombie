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
  exec "rm -rf html clean"


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
      return callback(err) if err
      fs.readFile source, "utf8", (err, text)->
        return callback(err) if err
        log "Creating #{target} ...", green
        exec "ronn --html #{source}", (err, stdout, stderr)->
          return callback(err) if err
          title = stdout.match(/<h1>(.*)<\/h1>/)[1]
          html = layout.replace("{{body}}", stdout).replace(/{{title}}/g, title).replace(/<h1>.*<\/h1>/, "")
          fs.writeFile target, html, "utf8", (err)->
            callback err, target

documentPages = (callback)->
  toHTML "README.md", (err)->
    return callback(err) if err
    exec "mv html/readme.html html/index.html", (err)->
      return callback(err) if err
      toHTML "TODO.md", (err)->
        return callback(err) if err
        exec "cp -f doc/*.css html/", (err)->
          callback err

documentSource = (callback)->
  log "Documenting source files ...", green
  exec "docco lib/**/*.coffee", (err)->
    return callback(err) if err
    log "Copying to html/source ...", green
    exec "mkdir -p html && cp -rf docs/ html/source && rm -rf docs", (err)->
      callback err

generateDocs = (callback)->
  log "Generating documentation ...", green
  documentPages (err)->
    return callback(err) if err
    documentSource (err)->
      callback err
task "doc:pages",  -> documentPages (err)-> throw err if err
task "doc:source",  -> documentSource (err)-> throw err if err
task "doc", "Generate documentation", -> generateDocs (err)-> throw err if err


# Testing
# -------

runTests = (callback)->
  log "Running test suite ...", green
  exec "vows --spec", (err, stdout, stderr)->
    log stdout, green
    log stderr, red
    callback err
task "test", "Run all tests", -> runTests (err)-> throw err if err


# Publishing
# ----------

publishDocs = (callback)->
  log "Publishing documentation ...", green
  generateDocs (err)->
    return callback(err) if err
    log "Uploading documentation ...", green
    exec "rsync -cr --del --progress html/ labnotes.org:/var/www/zombie/", callback
task "doc:publish", -> publishDocs (err)-> throw err if err

task "publish", "Publish new version (Git, NPM, site)", ->
  runTests (err)->
    throw err if err
    fs.readFile "package.json", "utf8", (err, package)->
      version = JSON.parse(package).version
      log "Tagging v#{version} ...", green
      exec "git tag v#{version}", ->
        exec "git push"

      log "Publishing to NPM ...", green
      exec "rm -rf clean && git checkout-index -a -f --prefix clean/", (err)->
        throw err if err
        exec "npm publish clean", (err)->
          throw err if err

    # Publish documentation
    publishDocs (err)-> throw err if err
