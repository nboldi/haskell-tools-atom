{CompositeDisposable} = require 'atom'
process = require 'child_process'

module.exports = ServerManager =
  subproc: null
  subscriptions: null
  running: false

  activate: () ->
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.commands.add 'atom-workspace',
      'haskell-tools:start-server': => @start()

    @subscriptions.add atom.commands.add 'atom-workspace',
      'haskell-tools:stop-server': => @stop()

    @subscriptions.add atom.commands.add 'atom-workspace',
      'haskell-tools:restart-server': => @restart()

    autoStart = atom.config.get("haskell-tools:start-automatically")
    if autoStart
      @start()

  dispose: () ->
    @stop()
    @subscriptions.dispose()

  restart: () ->
    @stop()
    # setting this will re-start the server when we are notified of the termination
    @running = true

  start: () ->
    console.log("start @running: " + @running)
    if @running
      atom.notifications.addInfo("Cannot start because Haskell Tools is already running.")
      return
    @running = true

    daemonPath = atom.config.get("haskell-tools:daemon-path")
    # FIXME: the value I get here can be undefined for some reason, regardless of default value given
    connectPort = atom.config.get("haskell-tools:connect-port") ? 4123

    # set verbose mode and channel log messages to our log here
    @subproc = process.spawn daemonPath, [connectPort, 'False']
    @subproc.stdout.on('data', (data) =>
      console.log('Haskell Tools: ' + data)
    );
    @subproc.stderr.on('data', (data) =>
      console.error('Haskell Tools: ' + data)
    );
    @subproc.on('close', (code) =>
      # restart the server if it was not intentionally closed
      console.log("terminated @running:"  + @running)
      if @running
        @running = false
        @start()
    );

  stop: () ->
    if !@running
      atom.notifications.addInfo("Cannot stop because Haskell Tools is not running.")
      return
    @running = false
    console.log("stopped @running:"  + @running)
    @subproc.kill('SIGINT')
