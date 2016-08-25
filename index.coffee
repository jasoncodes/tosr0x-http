yargs = require('yargs')

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
