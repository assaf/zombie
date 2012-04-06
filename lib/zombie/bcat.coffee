# A concise implementation of Ryan Tomayko's most excellent bcat:
# http://rtomayko.github.com/bcat/
{ exec, spawn } = require("child_process")
http = require("http")


COMMANDS =
  "Darwin":
    "default":  "open",
    "safari":   "open -a Safari",
    "firefox":  "open -a Firefox",
    "chrome":   "open -a Google\\ Chrome",
    "chromium": "open -a Chromium",
    "opera":    "open -a Opera",
    "curl":     "curl -s"
  "X11":
    "default":  "xdg-open"
    "firefox":  "firefox"
    "chrome":   "google-chrome"
    "chromium": "chromium"
    "mozilla":  "mozilla"
    "epiphany": "epiphany"
    "curl":     "curl -s"

ALIASES =
  "google-chrome": "chrome"
  "google chrome": "chrome"
  "gnome"        : "epiphany"


class BCat
  # Open browser to this url.
  open: (browser, port)->
    # Figure out which environment we're running in
    exec "uname", (err, stdout)->
      throw new Error("Sorry, I don't support your operating system") if err
      if /Darwin/.test(stdout)
        env = "Darwin"
      else if /(Linux|BSD)/.test(stdout)
        env = "X11"
      else
        env = "X11"

      # Figure out which browser to use.
      browser = ALIASES[browser] || browser || "default"
      command = COMMANDS[env][browser]
      unless command
        throw new Error("Sorry, don't know how to run #{browser}")

      # Launch the browser
      cmd = spawn(command, ["http://localhost:#{port}/"])
      cmd.stderr.on "data", (data)-> process.stdout.write data

  serve: (input, port)->
    # We're going to start by pausing the stream until we need it
    if input.setEncoding && input.pause
      input.setEncoding "utf8"
      input.pause()
    # World's smallest Web server or something like that
    server = http.createServer (req, res)->
      # No content type awareness in this release.
      res.writeHead 200, { "Content-Type": "text/html" }
      # Resume the stream and hand chunks over to the client.
      if input.resume && input.on
        input.resume()
        input.on "data", (chunk)->
          res.write chunk, "utf8"
        input.on "end", ->
          res.end()
          # Close the server and exit gracefully
          server.close()
          process.exit 0
      else
        # Must be a string then
        res.write input, "utf8"
        res.end()
        server.close()
        process.exit 0
    server.listen port

# Serve that input stream to a browser.
#
# - input -- A readable stream or a string; defaults to stdin
# - port -- Defaults to 8091
# - browser -- Will use OS default
exports.bcat = (input, port = 8091, browser)->
  bcat = new BCat
  input ||= process.openStdin()
  bcat.serve input, port
  console.log "open your browser on http://127.0.0.1:#{port}/"
  bcat.open browser, port
