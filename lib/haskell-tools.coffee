net = require 'net'
pkgHandler = require './package-handler'
exeLocator = require './exe-locator'
serverManager = require './server-manager'

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

  activate: (state) ->
    atom.notifications.addInfo("haskell-tools is started")
    exeLocator.locateExe()
    pkgHandler.activate()
    serverManager.activate()

  deactivate: ->
    serverManager.dispose()
    pkgHandler.dispose()

  serialize: ->

  refactor: (refactoring) ->
    atom.notifications.addInfo("Refactoring: " + refactoring)
