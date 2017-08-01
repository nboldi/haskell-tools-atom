{CompositeDisposable} = require 'atom'
pkgManager = require './package-manager'
exeLocator = require './exe-locator'
serverManager = require './server-manager'
clientManager = require './client-manager'
markerManager = require './marker-manager'
tooltipManager = require './tooltip-manager'
cursorManager = require './cursor-manager'
menuManager = require './menu-manager'
logger = require './logger'

# Main module for the plugin. Contains the packages configuration and
# activates/deactivates other modules.
module.exports = HaskellTools =
  subscriptions: null
  config:
    'start-automatically':
      type: 'boolean'
      description: 'If set the engine will be started when the editor starts.'
      default: false
    'refactored-packages':
      type: 'array'
      description: 'Contains the list of packages that should be loaded into the engine. Separated by commas.'
      default: []
      items:
        type: 'string'
    'connect-port':
      type: 'integer'
      description: 'The number of the port that the engine and the client uses for communication.'
      default: 4123
    'daemon-path':
      type: 'string'
      description: 'The location of the executable. If not set correctly, the plugin tries to find it in a few possible locations.'
      default: '<autodetect>'
    'watch-path':
      type: 'string'
      description: 'The location of the watch executable. It provides file system watching utility for daemon. If not set, the watch will use editor notifications, but it will not recognize changes from other programs.'
      default: '<watch-off>'
    'debug-mode':
      type: 'boolean'
      description: 'If set to true, the server and the client will log their communication in the clients console.'
      default: 'false'
    'rts-options':
      type: 'array'
      description: 'Run time options for the engine. Separated by commas. For possible options see https://downloads.haskell.org/~ghc/latest/docs/html/users_guide/runtime_control.html'
      default: []
      items:
        type: 'string'

  activate: (state) ->
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.commands.add 'atom-workspace',
      'haskell-tools:reset-plugin': => @resetPlugin()

    # disable commands in case the activation is not successful
    menuManager.disableCommand('haskell-tools:.*')
    menuManager.enableCommand('haskell-tools:reset-plugin')

    logger.log 'Haskell-tools plugin is activated'
    exeLocator.locateExe()
    serverManager.activate() # must go before pkgHandler, because it activates client manager that pkg handler uses
    clientManager.activate()
    serverManager.onStarted =>
      clientManager.connect(serverManager.watchService)
      logger.log 'enable stop server'
      menuManager.enableCommand('haskell-tools:stop-server')
      menuManager.enableCommand('haskell-tools:restart-server')
      menuManager.disableCommand('haskell-tools:start-server')
      menuManager.enableCommand('haskell-tools:refactor:.*')
    serverManager.onStopped =>
      clientManager.disconnect()
      menuManager.disableCommand('haskell-tools:stop-server')
      menuManager.disableCommand('haskell-tools:restart-server')
      menuManager.enableCommand('haskell-tools:start-server')
      menuManager.disableCommand('haskell-tools:refactor:.*')
    pkgManager.activate()
    clientManager.onConnect =>
      pkgManager.reconnect()
    pkgManager.onChange =>
      clientManager.whenReady =>
        {added, removed} = pkgManager.getChanges()
        clientManager.addPackages added
        clientManager.removePackages removed
    markerManager.activate()
    tooltipManager.activate()
    cursorManager.activate()

    menuManager.enableCommand('haskell-tools:start-server')


  deactivate: ->
    logger.log 'Haskell-tools plugin is deactivated'
    cursorManager.dispose()
    tooltipManager.dispose()
    markerManager.dispose()
    pkgManager.dispose()
    clientManager.dispose()
    serverManager.dispose()
    @subscriptions.dispose()

  resetPlugin: ->
    for name, settings of @config
      atom.config.set("haskell-tools.#{name}", settings.default)
    exeLocator.locateExe()
