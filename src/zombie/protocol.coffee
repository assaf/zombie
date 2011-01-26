net = require("net")

# Response types
ERROR = -1
SINGLE = 0
INTEGER = 1
BULK = 2
MULTI = 3


class Context
  constructor: (@stream)->
    this.reset()
  reset: ->
    @browser = new module.parent.exports.Browser(debug: debug)

# Server-side of the Zombie protocol.
# See http://redis.io/topics/protocol
class Protocol
  constructor: (port)->
    port ||= 8091
    active = false
    commands = {}
    debug = false
    server = net.createServer (stream)->
      # For each connection (stream): no delay, send data as soon as
      # it's available.
      stream.setNoDelay true
      input = ""
      context = new Context(stream)
      stream.on "data", (chunk)->
        # Collect input and process as much as possible.
        input = process(context, input + chunk)
      stream.on "end", ->
        # Collect input and process as much as possible.
        process context, input

    # ## Processing

    argc = 0 # Number of arguments
    argl = 0 # Size of next argument
    argv = [] # Received arguments

    # Process the currently available input, returns remaining input.
    process = (context, input)->
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
              queue context, argv
              argc = 0
              argv = []
            # See if we have more input to process.
            return process(context, input) if input.length > 0
        else
          # We're here because we expect to read the argument length:
          # $<number of bytes of argument 1> CR LF
          input = input.replace /^\$(\d+)\r\n/, (_, value)->
            argl = parseInt(value, 10)
            console.log "Expecting argument of size #{argl}" if debug
            return ""
          if argl
            return process(context, input)
          else
            throw new Error("Expecting $<argc>CRLF") if input.length > 0 && input[0] != "$"
      else
        # We're here because we epxect to read the number of arguments:
        # *<number of arguments> CR LF
        input = input.replace /^\*(\d+)\r\n/, (_, value)->
          argc = parseInt(value, 10)
          console.log "Expecting #{argc} arguments" if debug
          return ""
        if argc
          return process(context, input)
        else
          console.log input.length
          throw new Error("Expecting *<argc>CRLF") if input.length > 0 && input[0] != "*"
      return input

    # The last command in the queue.
    last = null
    # Queue next command to execute (since we're pipelining, we wait for
    # the previous command to complete and send its output first).
    queue = (context, argv)->
      command = {}
      # Invoke this command.
      command.invoke = ->
        if fn = commands[argv[0]]
          console.log "Executing #{argv.join(" ")}" if debug
          argv[0] = command.reply
          fn.apply context, argv
        else
          command.reply ERROR, "Unknown command #{argv[0]}"
      # Send a reply back to the client and if there's another command
      # in the queue, invoke it next.
      command.reply = (type, value)->
        respond context.stream, type, value
        last = command.next if last == command
        # Invoke next command in queue.
        if command.next
          process.nextTick -> command.next.invoke
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

    # ## Controlling

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


    # ## Commnands

    # For testing purposes.
    commands.ECHO = (reply, text)->
      reply SINGLE, text

    # Resets the context.  Discards current browser.
    commands.RESET = (reply)->
      this.reset()
      reply SINGLE, "OK"

    # Tells browser to visit <url>.
    #
    # Replies with OK.
    commands.VISIT = (reply, url)->
      this.browser.visit url
      reply SINGLE, "OK"
    # Tells browser to wait for all events to be processed.
    #
    # Replies with error or OK.
    commands.WAIT = (reply)->
      this.browser.wait (err)->
        if err
          reply ERROR, err.message
        else
          reply SINGLE, "OK"


exports.Protocol = Protocol

# ### Zombie.listen port, callback
# ### Zombie.listen socket, callback
#
# Ask Zombie to listen on the specified port for requests.  The default
# port is 8091, or you can specify a socket name.  The callback is
# invoked once Zombie is ready to accept new connections.
exports.listen = (port, callback)->
  protocol = new Protocol(port)
  protocol.listen callback
