{CompositeDisposable} = require 'atom'
net = require 'net'
RenameDialog = require './rename-dialog'

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
      'haskell-tools:refactor:rename-definition', () => @refactor('RenameDefinition')

    @subscriptions.add atom.commands.add 'atom-workspace',
      'haskell-tools:refactor:extract-binding', () =>
        editor = atom.workspace.getActivePaneItem()
        if not editor
          return
        file = editor.buffer.file.path
        range = editor.getSelectedBufferRange()

        dialog = new RenameDialog
        dialog.onSuccess ({answer}) =>
          @refactor('ExtractBinding', file, range, [answer.text()])
        dialog.attach()

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

  send: (data) ->
    if @ready
      @client.write JSON.stringify(data)
    else atom.notifications.addError("Haskell-tools: Server is not ready")

  checkServer: () ->
    @send {"tag":"KeepAlive","contents":[]}

  refactor: (refactoring, file, range, params) ->
    selection = "#{range.start.row}:#{range.start.column}-#{range.end.row}:#{range.end.column}"
    @send { 'tag': 'PerformRefactoring', 'refactoring': refactoring, 'modulePath': file, 'editorSelection': selection, 'details': params }
