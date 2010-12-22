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

# Handle error, do nothing if null
onerror = (err)->
  if err
    log err.stack, red
    process.exit -1


## Setup ##

# Setup development dependencies, not part of runtime dependencies.
task "setup", "Install development dependencies", ->
  log "Need Vows and Express to run test suite, installing ...", green
  exec "npm install \"vows@>=0.\"5", onerror
  exec "npm install \"express@>=1.0\"", onerror
  log "Need Ronn and Docco to generate documentation, installing ...", green
  exec "npm install \"ronn@>=0.3\"", onerror
  exec "npm install \"docco@>=0.3\"", onerror
  log "Need runtime dependencies, installing ...", green
  fs.readFile "package.json", "utf8", (err, package)->
    for name, version of JSON.parse(package).dependencies
      exec "npm install \"#{name}@#{version}\"", onerror


## Building ##

build = (callback)->
  exec "rm -rf lib && coffee -c -o lib src", callback
task "build", -> build onerror

task "clean", "Remove temporary files and such", ->
  exec "rm -rf clean html lib man1", onerror


## Testing ##

runTests = (callback)->
  log "Running test suite ...", green
  exec "vows --spec", (err, stdout, stderr)->
    log stdout, green
    log stderr, red
    callback err
task "test", "Run all tests", -> runTests onerror



## Documentation ##

# Markdown to HTML.
toHTML = (source, title, callback)->
  target = "html/#{path.basename(source, ".md").toLowerCase()}.html"
  fs.mkdir "html", 0777, ->
    fs.readFile "doc/_layout.html", "utf8", (err, layout)->
      onerror err
      fs.readFile source, "utf8", (err, text)->
        onerror err
        log "Creating #{target} ...", green
        exec "ronn --html #{source}", (err, stdout, stderr)->
          onerror err
          title ||= stdout.match(/<h1>(.*)<\/h1>/)[1]
          body = stdout.replace(/<h1>.*<\/h1>/, "")
          html = layout.replace("{{body}}", body).replace(/{{title}}/g, title)
          fs.writeFile target, html, "utf8", (err)->
            callback err, target

documentPages = (callback)->
  toHTML "README.md", "Zombie.js", (err)->
    onerror err
    exec "mv html/readme.html html/index.html", (err)->
      onerror err
      toHTML "TODO.md", null, (err)->
        onerror err
        toHTML "CHANGELOG.md", null, (err)->
          onerror err
          exec "cp -f doc/*.css html/", callback

documentSource = (callback)->
  log "Documenting source files ...", green
  exec "docco src/**/*.coffee", (err)->
    onerror err
    log "Copying to html/source ...", green
    exec "mkdir -p html && cp -rf docs/ html/source && rm -rf docs", callback

generateMan = (callback)->
  log "Generating man file ...", green
  fs.mkdir "man1", 0777, ->
    exec "ronn --roff README.md", (err, stdout, stderr)->
      onerror err
      fs.writeFile "man1/zombie.1", stdout, "utf8", callback

generateDocs = (callback)->
  log "Generating documentation ...", green
  documentPages (err)->
    onerror err
    documentSource (err)->
      onerror err
      generateMan callback
task "doc:pages",   -> documentPages onerror
task "doc:source",  -> documentSource onerror
task "doc:man",     -> generateMan onerror
task "doc", "Generate documentation", -> generateDocs onerror


## Publishing ##

publishDocs = (callback)->
  log "Publishing documentation ...", green
  generateDocs (err)->
    onerror err
    log "Uploading documentation ...", green
    exec "rsync -cr --del --progress html/ labnotes.org:/var/www/zombie/", callback
task "doc:publish", -> publishDocs onerror

task "publish", "Publish new version (Git, NPM, site)", ->
  runTests (err)->
    onerror err
    fs.readFile "package.json", "utf8", (err, package)->
      version = JSON.parse(package).version
      log "Tagging v#{version} ...", green
      exec "git tag v#{version}", ->
        exec "git push --tags origin master"

      log "Publishing to NPM ...", green
      exec "rm -rf clean && git checkout-index -a -f --prefix clean/ ; cp -rf man1 clean/", (err)->
        onerror err
        exec "coffee -c -o clean/lib clean/src", (err)->
          onerror err
          exec "npm publish clean", onerror

    # Publish documentation
    publishDocs onerror
