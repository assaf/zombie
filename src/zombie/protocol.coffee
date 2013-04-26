net = require("net")

# Response types
ERROR = -1
SINGLE = 0
INTEGER = 1
BULK = 2
MULTI = 3


class Context
  constructor: (@stream, @debug)->
    this.reset()
    argc = 0 # Number of arguments
    argl = 0 # Size of next argument
    argv = [] # Received arguments
    input = "" # Remaining input to process
    last = null # The last command in the queue.

    # Process the currently available input.
    this.process = (chunk)->
      input += chunk if chunk
      if argc
        # We're here because we're waiting for argc arguments to arrive
        # before we can execute the next requet.
        if argl
          # We're here because the length of the next argument is argl,
          # and we're waiting to receive that many bytes.
          if input.length >= argl
            # We have sufficient input for one argument, extract it from
            # the input and reset argl to await the next argument.
            argv.push input.slice(0, argl)
            input = input.slice(argl)
            argl = 0
            if argv.length == argc
              # We have all the arguments we expect, run a command and
              # reset argc/argv to await the next command.
              queue argv
              argc = 0
              argv = []
            # See if we have more input to process.
            this.process() if input.length > 0
        else
          # We're here because we expect to read the argument length:
          # $<number of bytes of argument 1> CR LF
          input = input.replace /^\$(\d+)\r\n/, (_, value)=>
            argl = parseInt(value, 10)
            console.log "Expecting argument of size #{argl}" if @debug
            return ""
          if argl
            this.process()
          else
            throw new Error("Expecting $<argc>CRLF") if input.length > 0 && input[0] != "$"
      else
        # We're here because we epxect to read the number of arguments:
        # *<number of arguments> CR LF
        input = input.replace /^\*(\d+)\r\n/, (_, value)=>
          argc = parseInt(value, 10)
          console.log "Expecting #{argc} arguments" if @debug
          return ""
        if argc
          this.process()
        else
          throw new Error("Expecting *<argc>CRLF") if input.length > 0 && input[0] != "*"

    # Queue next command to execute (since we're pipelining, we wait for
    # the previous command to complete and send its output first).
    queue = (argv)=>
      command = {}
      # Invoke this command.
      command.invoke = =>
        try
          if fn = this[argv[0].toLowerCase()]
            console.log "Executing #{argv.join(" ")}" if debug
            argv[0] = command.reply
            fn.apply this, argv
          else
            command.reply ERROR, "Unknown command #{argv[0]}"
        catch error
          command.reply ERROR, "Failed on #{argv[0]}: #{error.message}"
      # Send a reply back to the client and if there's another command
      # in the queue, invoke it next.
      command.reply = (type, value)=>
        respond @stream, type, value
        last = command.next if last == command
        # Invoke next command in queue.
        if command.next
          process.nextTick -> command.next.invoke()
      if last
        # There's another command in the queue, add us at the end.
        last.next = command
        last = command
      else
        # We're the next command in the queue, run now.
        last = command
        command.invoke()

    # Send a response of the specified type.
    respond = (stream, type, value)->
      switch type
        when ERROR then stream.write "-#{value.message}\r\n"
        when SINGLE then stream.write "+#{value}\r\n"
        when INTEGER then stream.write ":#{value}\r\n"
        when BULK
          if value
            stream.write "$#{value.length}\r\n"
            stream.write value # could be Buffer
            stream.write "\r\n"
          else
            stream.write "$-1\r\n"
        when MULTI
          if value
            stream.write "*#{value.length}\r\n"
            for item in value
              if item
                stream.write "$#{item.length}\r\n"
                stream.write item # could be Buffer
                stream.write "\r\n"
              else
                stream.write "$-1\r\n"
          else
            stream.write "*-1\r\n"

  # Turns debugging on.  To turn debugging off, pass 0 or false as the
  # argument (no argument required to turn it off).
  debug: (reply, debug)->
    this.browser.debug = (debug == "0" || debug == "off")

  # For testing purposes.
  echo: (reply, text)->
    reply SINGLE, text

  # Resets the context.  Discards current browser.
  reset: (reply)->
    @browser = new module.parent.exports.Browser(debug: @debug)
    reply SINGLE, "OK" if reply

  # Returns the status code of the request for loading the window.
  status: (reply)-> reply INTEGER, @browser.statusCode || 0

  # Tells browser to visit <url>.
  visit: (reply, url)->
    @browser.visit url
    reply SINGLE, "OK"

  # Tells browser to wait for all events to be processed.
  #
  # Replies with error or OK.
  wait: (reply)->
    @browser.wait (error)->
      if error
        reply ERROR, error.message
      else
        reply SINGLE, "OK"


# Server-side of the Zombie protocol.
# See http://redis.io/topics/protocol
class Protocol
  constructor: (port)->
    debug = false
    server = net.createServer (stream)->
      # For each connection (stream): no delay, send data as soon as
      # it's available.
      stream.setNoDelay true
      context = new Context(stream, debug)
      stream.on "data", (chunk)-> context.process chunk

    # ## Controlling

    active = false
    port ||= 8091
    # Start listening to incoming requests.
    this.listen = (callback)->
      listener = (err)->
        active = true unless err
        callback err if callback
      if typeof port is "number"
        server.listen port, "127.0.0.1", listener # don't listen on 0.0.0.0
      else
        server.listen port, listener # port is actually a socket

    this.close = ->
      if active
        server.close()
        active = false

    # Returns true if connection is open and active.
    this.__defineGetter__ "active", ->active


exports.Protocol = Protocol

# ### Zombie.listen port, callback
# ### Zombie.listen socket, callback
# ### Zombie.listen callback
#
# Ask Zombie to listen on the specified port for requests.  The default
# port is 8091, or you can specify a socket name.  The callback is
# invoked once Zombie is ready to accept new connections.
exports.listen = (port, callback)->
  [port, callback] = [8091, port] unless callback
  protocol = new Protocol(port)
  protocol.listen callback
