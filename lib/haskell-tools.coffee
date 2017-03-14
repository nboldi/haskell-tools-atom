net = require 'net'
pkgHandler = require './package-handler'
exeLocator = require './exe-locator'
serverManager = require './server-manager'
markerManager = require './marker-manager'
cursorManager = require './cursor-manager'
logger = require './logger'

# Main module for the plugin. Contains the packages configuration and
# activates/deactivates other modules.
module.exports = HaskellTools =
  config:
    'start-automatically':
      type: 'boolean'
      default: false
    'refactored-packages':
      type: 'array'
      default: []
      items:
        type: 'string'
    'connect-port':
      type: 'integer'
      default: 4123
    'daemon-path':
      type: 'string'
      default: '<autodetect>'
    'debug-mode':
      type: 'boolean'
      default: 'false'

  activate: (state) ->
    logger.log 'Haskell-tools plugin is activated'
    exeLocator.locateExe()
    serverManager.activate() # must go before pkgHandler, because it activates client manager that pkg handler uses
    pkgHandler.activate()
    markerManager.activate()
    cursorManager.activate()

  deactivate: ->
    logger.log 'Haskell-tools plugin is deactivated'
    cursorManager.dispose()
    markerManager.dispose()
    pkgHandler.dispose()
    serverManager.dispose()
