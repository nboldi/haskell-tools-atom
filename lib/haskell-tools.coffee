net = require 'net'
pkgHandler = require './package-handler'
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
  config:
    'start-automatically':
      type: 'boolean'
      description: 'If set the engine will be started when the editor starts.'
      default: false
    'refactored-packages':
      type: 'array'
      description: 'Contains the list of packages that should be loaded into the engine.'
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
    'debug-mode':
      type: 'boolean'
      description: 'If set to true, the server and the client will log their communication in the clients console.'
      default: 'false'

  activate: (state) ->
    logger.log 'Haskell-tools plugin is activated'
    exeLocator.locateExe()
    serverManager.activate() # must go before pkgHandler, because it activates client manager that pkg handler uses
    clientManager.activate()
    serverManager.onStarted =>
      clientManager.connect()
      logger.log 'enable stop server'
      menuManager.enableCommand('haskell-tools:stop-server')
      menuManager.enableCommand('haskell-tools:restart-server')
      menuManager.disableCommand('haskell-tools:start-server')
    serverManager.onStopped =>
      clientManager.disconnect()
      menuManager.disableCommand('haskell-tools:stop-server')
      menuManager.disableCommand('haskell-tools:restart-server')
      menuManager.enableCommand('haskell-tools:start-server')
    pkgHandler.activate()
    markerManager.activate()
    tooltipManager.activate()
    cursorManager.activate()
    menuManager.disableCommand('haskell-tools:stop-server')
    menuManager.disableCommand('haskell-tools:restart-server')

  deactivate: ->
    logger.log 'Haskell-tools plugin is deactivated'
    cursorManager.dispose()
    tooltipManager.dispose()
    markerManager.dispose()
    pkgHandler.dispose()
    clientManager.dispose()
    serverManager.dispose()
