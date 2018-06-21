{CompositeDisposable,Emitter} = require 'atom'
process = require 'child_process'
fs = require 'fs'
logger = require './logger'
exeLocator = require './exe-locator'

# Runs the server executable. Starts, stops and restarts it as needed.
# The executable does NOT restart automatically if the executable path changes.
module.exports = ServerManager =
  subproc: null # The subprocess object
  subscriptions: null
  running: false
  watchService: false
  emitter: new Emitter # generates started and stopped events

  activate: () ->
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.commands.add 'atom-workspace',
      'haskell-tools:start-server': => @start()

    @subscriptions.add atom.commands.add 'atom-workspace',
      'haskell-tools:stop-server': => @stop()

    @subscriptions.add atom.commands.add 'atom-workspace',
      'haskell-tools:restart-server': => @restart()

    autoStart = atom.config.get("haskell-tools.start-automatically")
    if autoStart
      @start()

  dispose: () ->
    @stop()
    @subscriptions.dispose()

  restart: () ->
    @stop()
    @subproc.once 'close', => @start()

  # Starts the executable.
  start: () ->
    useExisting = atom.config.get("haskell-tools.use-existing")
    if useExisting
      @emitter.emit 'started'
      return
    if @running
      atom.notifications.addInfo("Cannot start because Haskell Tools is already running.")
      return

    daemonPath = atom.config.get("haskell-tools.daemon-path")
    connectPort = atom.config.get("haskell-tools.connect-port")
    rtsOptions = atom.config.get("haskell-tools.rts-options")
    cmdOptions = atom.config.get("haskell-tools.cmd-options")
    watchPath = atom.config.get("haskell-tools.watch-path")

    if !daemonPath
      atom.notifications.addError("Cannot start because the location of the daemon executable is not set up. Please go to Haskell/Settings and set it manually.")
      return

    # set verbose mode and channel log messages to our log here

    params = ["--port", connectPort]
    if fs.existsSync(watchPath)
      params.push "--watch-exe"
      params.push watchPath
      @watchService = true
    params = params.concat cmdOptions
    if rtsOptions.length > 0
      params.push '+RTS'
      params = params.concat rtsOptions
    logger.log('Starting server with parameters: ' + daemonPath + ' ' + params)
    @subproc = process.spawn(daemonPath, params)
    @running = true
    @subproc.stdout.on('data', (data) =>
      logger.log('Haskell Tools: ' + data)
    )
    @subproc.stderr.on('data', (data) =>
      logger.error('Haskell Tools: ' + data)
    )
    @subproc.on('close', (code) =>
      # restart the server if it was not intentionally closed
      if @running
        @running = false
        atom.notifications.addError("Unfortunately the server crashed. Restarting after 1s.")
        restart = () =>
          @start()
        setTimeout restart, 1000
    );
    @emitter.emit 'started'

  # Sends a kill signal to the process
  stop: () ->
    useExisting = atom.config.get("haskell-tools.use-existing")
    if useExisting
      @emitter.emit 'stopped'
      @running = false
      return
    if !@running
      atom.notifications.addInfo("Cannot stop because Haskell Tools is not running.")
      return
    @emitter.emit 'stopped'
    @running = false
    @subproc.kill('SIGINT')

  onStarted: (callback) -> @emitter.on 'started', callback
  onStopped: (callback) -> @emitter.on 'stopped', callback
