{CompositeDisposable} = require 'atom'
net = require 'net'
pkgHandler = require './package-handler'
exeLocator = require './exe-locator'
serverManager = require './server-manager'

module.exports = HaskellTools =
  subscriptions: null
  connection: null

  domain: 'localhost'
  port: 4123

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
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.commands.add 'atom-workspace',
      'haskell-tools:refactor:rename-definition': => @refactor('RenameDefinition')

    exeLocator.locateExe()

    @subscriptions.add atom.commands.add 'atom-workspace',
      'haskell-tools:refactor:extract-binding': => @refactor('ExtractBinding')

    pkgHandler.activate()
    serverManager.activate()

  deactivate: ->
    @subscriptions.dispose()
    pkgHandler.dispose()
    serverManager.dispose()

  serialize: ->

  refactor: (refactoring) ->
    atom.notifications.addInfo("Refactoring: " + refactoring)
