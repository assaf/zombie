# http://redis.io/topics/protocol


# Response types
ERROR = -1
SINGLE = 0
INTEGER = 1
BULK = 2
MULTI = 3

class Protocol
  constructor: (browser)->
    # Processing
    # ----------

    stream.setNoDelay true
    input = ""
    stream.on "data", (chunk)->
      input += chunk
      process()
    stream.on "end", process

    argc = 0 # Number of arguments
    argl = 0 # Size of next argument
    argv = [] # Received arguments
    # Process the currently available input.
    process = ->
      if argc
        # Waiting for argc arguments to arrive
        if argl
          if input.length >= argl
            # We have sufficient input for one argument, extract it from
            # the input and reset argl to await the next argument.
            argv.push input.slice(0, argl)
            input = input.silce(argl)
            argl = 0
            if argv.length == argc
              # We have all the arguments we expect, run a command and
              # reset argc/argv to await the next command.
              command argv
              argc = 0
              argv = []
            process() if input.length > 0
        else
          # Expect $<number of bytes of argument 1> CR LF
          input = input.replace /^\$(\d+)\r\n/, (_, value)->
            argl = parseInt(value, 10)
            console.log "Expecting argument of size #{argl}"
            return ""
          if argl
            process()
          else
            throw new Error("Expecting $<argc>CRLF") if input.length > 0 && input[0] != "$"
      else
        # Expect *<number of arguments> CR LF
        input = input.replace /^\*(\d+)\r\n/, (_, value)->
          argc = parseInt(value, 10)
          console.log "Expecting #{argc} arguments"
          return ""
        if argc
          process()
        else
          throw new Error("Expecting *<argc>CRLF") if input.length > 0 && input[0] != "*"
          
    # Run command from arguments.
    command = (argv)->
      try
        cmd = argv[0]
        argv[0] = queue()
        this[cmd].apply this, argv
      catch error
        stream.write "-#{error.message}\r\n"

    # Last request in the queue.
    last = nil
    # Queue this request and return a reply object.  The reply object can
    # be invoked at any time, but will only send a response when there are
    # no previous pending request in the queue, to guarantee order when
    # pipelining.
    queue = ->
      reply = (type, value, callback)->
        # Send request back to client, invoke callback if supplied, and
        # trigger the next request (if ready)
        this.send = ->
          respondWith type, value
          callback() if callback
          last = next if last == this
          next.send() if next && next.send
        # Don't send yet if waiting for a previous reply
        return if reply.previous
        this.send()
      # Add this request to end of queue, double linked list so we know
      # there's a previous request and previous request can trigger us.
      last.next = reply if last
      reply.previous = last
      last = reply
      return reply

    # Send a response of the specified type. 
    respondWith = (type, value)->
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


  # Commands
  # --------

  # Wait for all events to be processed, then reply OK.
  wait: (reply)->
    @browser.wait (error)->
      if error
        reply ERROR, error
      else
        reply SINGLE, "OK"

  # Shutdown command.
  shutdown: (reply)->
    reply SINGLE, "OK", =>
      @stream.end()
      @stream.destroy()
