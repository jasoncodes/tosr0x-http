_ = require('lodash')
yargs = require('yargs')
net = require('net')
express = require('express')
bodyParser = require('body-parser')
os = require('os')
process = require('process')
mqtt = require('mqtt')

argv = yargs
  .env('TOSR0X_HTTP')
  .usage('Usage: $0 [options]')
  .strict()
  .demandCommand(0, 0, '', 'Invalid argument')
  .help('help')
  .option('device-host'
    describe: 'Hostname/IP address of TOSR0x WiFly device'
    type: 'string'
    requiresArg: true
    required: true
  )
  .option('device-port'
    describe: 'TCP port number to connect to'
    type: 'number'
    requiresArg: true
    default: 2000
  )
  .option('listen-host'
    describe: 'Hostname to listen on'
    type: 'string'
    requiresArg: true
  )
  .option('listen-port'
    describe: 'TCP port to listen on'
    type: 'number'
    requiresArg: true
    default: 8020
  )
  .option('mqtt-host'
    describe: 'MQTT hostname'
    type: 'string'
    requiresArg: true
  )
  .option('mqtt-port'
    describe: 'MQTT port'
    type: 'number'
    requiresArg: true
    default: 1883
  )
  .option('mqtt-user'
    describe: 'MQTT username'
    type: 'string'
    requiresArg: true
  )
  .option('mqtt-pass'
    describe: 'MQTT password'
    type: 'string'
    requiresArg: true
  )
  .option('mqtt-prefix'
    describe: 'MQTT topic prefix'
    type: 'string'
    requiresArg: true
  )
  .implies('mqtt-host', 'mqtt-prefix')
  .argv

bufferedData = null
queue = null

initQueue = ->
  bufferedData = new Buffer([])
  queue = []
initQueue()

errorQueue = (message) ->
  while queue.length > 0
    item = queue.shift()
    item.callback?(new Error(message))

idleCheck = ->
  socket.setTimeout 5000, ->
    if queue.length
      errorQueue('timeout')
      socket.destroy()
    idleCheck()

expectHello = ->
  queue.push
    length: 7
    callback: (error, data) ->
      if error
        console.log "hello error: #{error}"
        return
      unless data.toString() == '*HELLO*'
        console.log 'Expected hello from WiFly'
        socket.destroy()
        return

checkModuleId = ->
  socket.write 'Z'
  queue.push
    length: 2
    callback: (error, data) ->
      if error
        console.log "module ID check error: #{error}"
        return
      unless data[0] == 15
        console.log 'Expected TOSR0X module ID'
        socket.destroy()
        return

getTemperature = (callback) ->
  if !connected
    callback?(new Error('not connected'))
    return
  socket.write 'a'
  queue.push
    length: 2
    callback: (error, data) ->
      if error
        callback?(error)
      else
        temperature = (data[0]*256 + data[1])/16
        temperature = Math.round(temperature * 10) / 10
        callback?(null, temperature)

getStates = (callback) ->
  if !connected
    callback?(new Error('not connected'))
  socket.write '['
  queue.push
    length: 1
    callback: (error, data) ->
      if error
        callback?(error)
      else
        states = {}
        for i in [0..7]
          states[i+1] = (data[0] & (1 << i)) != 0
        callback?(null, states)

setState = (relay, state) ->
  if !connected
    throw new Error('not connected')
  if relay < 0 || relay > 8
    throw new Error('relay out of range')
  cmd = if state then 100 else 110
  socket.write String.fromCharCode(cmd + relay)

EventEmitter = require('events')
class Device extends EventEmitter
device = new Device

device.on 'connect', ->
  console.log 'device connected'

device.on 'disconnect', ->
  console.log 'device disconnected'

socket = new net.Socket()
connected = false
lastConnectErrorMessage = null
socket.on 'data', (data) ->
  bufferedData = Buffer.concat([bufferedData, data])
  while queue.length > 0 and bufferedData.length >= queue[0].length
    item = queue.shift()
    data = bufferedData.slice(0, item.length)
    bufferedData = bufferedData.slice(item.length)
    item.callback?(null, data)
socket.on 'connect', ->
  connected = true
  lastConnectErrorMessage = null
  initQueue()
  expectHello()
  checkModuleId()
  idleCheck()
  device.emit 'connect'
socket.on 'close', ->
  if connected
    device.emit 'disconnect'
  connected = false
  errorQueue('disconnected')
  setTimeout connectToDevice, 5000
socket.on 'error', (error) ->
  if error.message != lastConnectErrorMessage
    console.log "device connection error: #{error.message}"
    lastConnectErrorMessage = error.message

connectToDevice = ->
  socket.connect argv['device-port'], argv['device-host']
connectToDevice()

setInterval ->
  checkModuleId() if connected
, 30000

app = express()

app.use(bodyParser.json())
app.use(bodyParser.urlencoded(extended: true))

app.use(express.static("#{__dirname}/public"))

router = express.Router()
app.use '/', router

router.get '/status', (request, response) ->
  getTemperature (error, temperature) ->
    if error
      response.status(503).json(error: error.message)
    else
      getStates (error, states) ->
        if error
          response.status(503).json(error: error.message)
        else
          response.status(200).json(
            temperature: temperature
            states: states
          )

parseRelayStates = (states) ->
  unless _.isPlainObject(states)
    throw new Error('states must be an object')
  _.map states, (state, relay) ->
    relay: parseRelayNumber(relay)
    state: parseStateValue(state)

parseRelayNumber = (value) ->
  relay = Number(value)
  if Number.isNaN(relay)
    throw new Error('relay must be a number')
  unless Number.isInteger(relay)
    throw new Error('relay must be an integer')
  unless relay >= 0 and relay <= 8
    throw new Error('relay out of range')
  relay

parseStateValue = (value) ->
  if typeof(value) == 'string'
    value.toLowerCase()

  switch value
    when true, 'true'
      true
    when false, 'false'
      false
    else
      throw new Error('invalid state value')

router.post '/update', (request, response) ->
  try
    entries = parseRelayStates(request.body)
  catch error
    response.status(400).json(error: error.message)
    return

  allEntry = _.find(entries, (entry) -> entry.relay == 0)
  if allEntry && _.find(entries, (entry) -> entry.state != allEntry.state)
    response.status(409).json(error: 'conflicting state changes')
    return

  for entry in entries
    try
      setState entry.relay, entry.state
    catch error
      response.status(503).json(error: error.message)
      return

  getStates (error, states) ->
    if error
      response.status(503).json(error: error.message)
    else
      for entry in entries
        if entry.relay == 0 && !!_.find(_.values(states)) != entry.state
          response.status(422).json(error: "Could not change relays to #{entry.state}")
          return
        if entry.relay > 0 && states[entry.relay] != entry.state
          response.status(422).json(error: "Could not change relay #{entry.relay} to #{entry.state}")
          return
      response.status(204).send()

app.listen argv['listen-port'], argv['listen-host'], ->
  console.log 'started'

if argv['mqtt-host']
  client = mqtt.connect
    host: argv['mqtt-host']
    port: argv['mqtt-port']
    username: argv['mqtt-user']
    password: argv['mqtt-pass']
    clientId: "tosr0x-#{os.hostname().split('.')[0]}-#{process.pid}"

  client.on 'connect', ->
    console.log 'mqtt connected'
  client.on 'offline', ->
    console.log 'mqtt offline'
  client.on 'error', ->
    console.log 'mqtt error'
