{ Vows, assert, brains, Browser } = require("./helpers")
NET = require("net")


listen = (callback)=>
  if @active
    process.nextTick callback
  else
    @active = true
    Browser.listen 8091, (error)=>
      brains.ready =>
        process.nextTick -> callback error

class Client
  constructor: ->
    stream = NET.createConnection(8091, "localhost")
    stream.setNoDelay true
    data = ""
    stream.on "data", (chunk)=>
      @response = undefined
      error = null
      data += chunk
      while /\r\n/.test(data)
        data = data.replace /^\-(.*)\r\n/, (_, error)->
          error = new Error(error)
          return ""
        data = data.replace /^\+(.*)\r\n/, (_, string)=>
          @response = string
          return ""
        data = data.replace /^\:(\d+)\r\n/, (_, integer)=>
          @response = parseInt(integer, 10)
          return ""
        length = null
        data = data.replace /^\$(\d+)\r\n/, (_, a)->
          length = parseInt(a, 10)
          return ""
        if length == -1
          @response = null
        else if length != null
          @response = data.slice(0, length)
          data = data.slice(length + 2)
        length = null
        data = data.replace /^\*(\d+)\r\n/, (_, a)->
          length = parseInt(a, 10)
          return ""
        if length == -1
          @response = null
        else if length != null
          @response = []
          for i in [0...length]
            size = 0
            data = data.replace /^\$(\d+)\r\n/, (_, b)->
              size = parseInt(b, 10)
              return ""
            if size >= 0
              value = data.slice(0, size)
              data = data.slice(size + 2)
              @response.push value
            else
              @response.push null
      if error
        @callback error
      else if @response != undefined
        @callback null, this
    this.send = (commands, callback)->
      @callback = callback
      if commands.join
        commands = [commands] unless commands[0].join
        stream.write commands.map((argv)-> "*#{argv.length}\r\n" + argv.map((arg)-> "$#{arg.length}\r\n#{arg}").join("") ).join("")
      else
        stream.write "*1\r\n$#{commands.length}\r\n#{commands}"


execute = (tests)->
  commands = tests.commands
  delete tests.commands
  tests.topic = (client)->
    listen (error)=>
      client ||= new Client
      client.send commands, @callback
  return tests


Vows.describe("Protocol").addBatch(
  ###
  "visit":
    execute
      commands: ["VISIT", "http://localhost:3003/"]
      "should return OK": (client)-> assert.equal client.response, "OK"

  "visit and wait":
    execute
      commands: [["VISIT", "http://localhost:3003/"], ["WAIT"]]
      "should return OK": (client)-> assert.equal client.response, "OK"
      "status":
        execute
          commands: "STATUS"
          "should return status code": (client)-> assert.equal client.response, 200
  ###
  "broken": {}
).export(module)
