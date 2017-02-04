net = require 'net'
pkgHandler = require './package-handler'
exeLocator = require './exe-locator'
serverManager = require './server-manager'
markerManager = require './marker-manager'
cursorManager = require './cursor-manager'

module.exports = HaskellTools =
  subscriptions: null
  connection: null

  domain: 'localhost'

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
    atom.notifications.addInfo("haskell-tools is started")
    exeLocator.locateExe()
    pkgHandler.activate()
    markerManager.activate()
    serverManager.activate()
    cursorManager.activate()

  deactivate: ->
    cursorManager.dispose()
    serverManager.dispose()
    markerManager.dispose()
    pkgHandler.dispose()

  serialize: ->
