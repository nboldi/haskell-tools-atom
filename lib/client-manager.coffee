{CompositeDisposable} = require 'atom'
net = require 'net'

module.exports = ClientManager =
  subscriptions: null
  client: null
  ready: false
  stopped: true

  activate: () ->
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.commands.add 'atom-workspace',
      'haskell-tools:check-server': => @checkServer()

    @subscriptions.add atom.commands.add 'atom-workspace',
      'haskell-tools:refactor:rename-definition': => @refactor('RenameDefinition')

    @subscriptions.add atom.commands.add 'atom-workspace',
      'haskell-tools:refactor:extract-binding': => @refactor('ExtractBinding')

    autoStart = atom.config.get("haskell-tools:start-automatically")
    if autoStart
      @connect()

  connect: () ->
    if @ready
      return # already connected

    @client = new net.Socket
    @stopped = false
    connectPort = atom.config.get("haskell-tools:connect-port") ? 4123

    @client.connect connectPort, '127.0.0.1', () =>
      console.log('ClientManager: Connected to Haskell Tools')
      @ready = true

    @client.on 'data', (msg) =>
      console.log('ClientManager: Received: ' + msg)
      data = JSON.parse(msg)
      switch data.tag
        when "KeepAliveResponse" then atom.notifications.addInfo 'Server is up and running'
        when "ErrorMessage" then atom.notifications.addError data.errorMsg
        else atom.notifications.addError('Unrecognized response from server: ' + data)

    @client.on 'close', () =>
      if @stopped
        console.log('ClientManager: Connection closed intentionally.')
        return
      console.log('ClientManager: Connection closed. Reconnecting after 1s')
      @ready = false
      callback = () => @connect()
      setTimeout callback, 1000

  dispose: () ->
    @disconnect()
    @subscriptions.dispose()

  disconnect: () ->
    @ready = false
    @stopped = true
    @client.destroy()

  send: (msg) ->
    if @ready
      @client.write msg
    else atom.notifications.addError("Haskell-tools: Server is not ready")

  checkServer: () ->
    @send '{"tag":"KeepAlive","contents":[]}'
