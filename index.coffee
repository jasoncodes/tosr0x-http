yargs = require('yargs')
net = require('net')

argv = yargs
  .env('TOSR0X_HTTP')
  .usage('Usage: $0 [options]')
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
  console.log 'device connected'
  connected = true
  lastConnectErrorMessage = null
  initQueue()
  expectHello()
  checkModuleId()
socket.on 'close', ->
  if connected
    console.log 'device disconnected'
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
