fs            = require("fs")
path          = require("path")
{spawn, exec} = require("child_process")
sys           = require("sys")

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
    sys.puts "#{red}#{err.stack}#{reset}"
    process.stdout.on "drain", -> process.exit -1


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
  log "Compiling CoffeeScript to JavaScript ...", green
  exec "rm -rf lib && coffee -c -l -b -o lib src", (err, stdout)->
    log stdout + "Done", green
    callback err
task "build", "Compile CoffeeScript to JavaScript", -> build onerror

task "watch", "Continously compile CoffeeScript to JavaScript", ->
  cmd = spawn("coffee", ["-cw", "-o", "lib", "src"])
  cmd.stdout.on "data", (data)-> sys.print green + data + reset
  cmd.on "error", onerror
  

task "clean", "Remove temporary files and such", ->
  exec "rm -rf html lib man1", onerror


## Testing ##

runTests = (callback)->
  log "Running test suite ...", green
  exec "vows --spec", (err, stdout)->
    sys.puts stdout
    callback err
task "test", "Run all tests", -> runTests onerror



## Documentation ##

# Markdown to HTML.
toHTML = (source, callback)->
  target = "html/#{path.basename(source, ".md").toLowerCase()}.html"
  fs.mkdir "html", 0777, ->
    fs.readFile "doc/_layout.html", "utf8", (err, layout)->
      onerror err
      fs.readFile source, "utf8", (err, text)->
        onerror err
        log "Creating #{target}", green
        exec "ronn --html #{source}", (err, stdout, stderr)->
          onerror err
          [title, subtitle] = stdout.match(/<h1>(.*)<\/h1>/)[1].split(" -- ")
          title = title.replace(/\(\d\)/, "")
          body = stdout.replace(/<h1>.*<\/h1>/, "")
          html = layout.replace("{{body}}", body).replace(/{{title}}/g, title).replace(/{{subtitle}}/g, subtitle || "")
          fs.writeFile target, html, "utf8", (err)->
            callback err, target

documentPages = (callback)->
  toHTML "README.md", (err)->
    onerror err
    exec "mv html/readme.html html/index.html", (err)->
      onerror err
      toHTML "TODO.md", (err)->
        onerror err
        toHTML "CHANGELOG.md", (err)->
          onerror err
          sys.puts ""
          exec "cp -f doc/*.css html/", callback

documentSource = (callback)->
  log "Documenting source files ...", green
  exec "docco src/*.coffee src/**/*.coffee", (err, stdout, stderr)->
    log stdout, green
    onerror err
    log "Copying to html/source", green
    exec "mkdir -p html && cp -rf docs/ html/source && rm -rf docs", callback

generateMan = (callback)->
  log "Generating man file ...", green
  fs.mkdir "man1", 0777, ->
    exec "ronn --roff README.md", (err, stdout, stderr)->
      onerror err
      log "Done", green
      fs.writeFile "man1/zombie.1", stdout, "utf8", callback

generateDocs = (callback)->
  log "Generating documentation ...", green
  documentPages (err)->
    onerror err
    documentSource (err)->
      onerror err
      generateMan callback
task "doc:pages",  "Generate documentation for main pages",    -> documentPages onerror
task "doc:source", "Generate documentation from source files", -> documentSource onerror
task "doc:man",    "Generate man pages",                       -> generateMan onerror
task "doc",        "Generate all documentation",               -> generateDocs onerror


## Publishing ##

publishDocs = (callback)->
  log "Publishing documentation ...", green
  generateDocs (err)->
    onerror err
    log "Uploading documentation ...", green
    exec "rsync -cr --del --progress html/ labnotes.org:/var/www/zombie/", (err, stdout, stderr)->
      log stdout, green
      callback err
task "doc:publish", "Publish documentation to site", -> publishDocs onerror

task "publish", "Publish new version (Git, NPM, site)", ->
  runTests (err)->
    onerror err
    fs.readFile "package.json", "utf8", (err, package)->
      version = JSON.parse(package).version
      log "Tagging v#{version} ...", green
      exec "git tag v#{version}", (err, stdout, stderr)->
        log stdout, green
        exec "git push --tags origin master", (err, stdout, stderr)->
          log stdout, green

      log "Publishing to NPM ...", green
      build (err)->
        onerror err
        exec "npm publish ./", (err, stdout, stderr)->
          log stdout, green
          onerror err

    # Publish documentation
    publishDocs onerror
