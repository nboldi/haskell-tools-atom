{CompositeDisposable} = require 'atom'
process = require 'child_process'

module.exports = serverManager =
  subproc: null
  subscriptions: null

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

  start: () ->
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
      console.log('Haskell Tools daemon had been terminated.')
      # TODO: restart on termination
    );

  stop: () ->
    @subproc.kill('SIGINT')
