{CompositeDisposable} = require 'atom'
net = require 'net'
NameDialog = require './name-dialog'
markerManager = require './marker-manager'

module.exports = ClientManager =
  subscriptions: null
  client: null
  ready: false
  stopped: true
  jobs: []

  activate: () ->
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.commands.add 'atom-workspace',
      'haskell-tools:check-server': => @checkServer()

    @subscriptions.add atom.workspace.observeTextEditors (editor) =>
      @subscriptions.add editor.onDidSave ({path}) =>
        packages = atom.config.get("haskell-tools.refactored-packages")
        for pack in packages
          if path.startsWith pack
            @whenReady () => @reload [path], []
            return

    @subscriptions.add atom.commands.onDidDispatch (event) =>
      if event.type == 'tree-view:remove'
        removed = event.target.getAttribute('data-name')
        packages = atom.config.get("haskell-tools.refactored-packages")
        for pack in packages
          if removed.startsWith pack
            @whenReady () => @reload [], [removed]
            return

    # Register refactoring commands

    @subscriptions.add atom.commands.add 'atom-workspace',
      'haskell-tools:refactor:rename-definition', () => @refactor 'RenameDefinition'

    @subscriptions.add atom.commands.add 'atom-workspace',
      'haskell-tools:refactor:generate-signature', () => @refactor 'GenerateSignature'

    @subscriptions.add atom.commands.add 'atom-workspace',
      'haskell-tools:refactor:extract-binding', () => @refactor 'ExtractBinding'

    @subscriptions.add atom.commands.add 'atom-workspace',
      'haskell-tools:refactor:inline-binding', () => @refactor 'InlineBinding'

    @subscriptions.add atom.commands.add 'atom-workspace',
      'haskell-tools:refactor:float-out', () => @refactor 'FloatOut'

    @subscriptions.add atom.commands.add 'atom-workspace',
      'haskell-tools:refactor:organize-imports', () => @refactor 'OrganizeImports'

    @subscriptions.add atom.commands.add 'atom-workspace',
      'haskell-tools:refactor:generate-exports', () => @refactor 'GenerateExports'

    autoStart = atom.config.get("haskell-tools.start-automatically")
    if autoStart
      @connect()

  connect: () ->
    if @ready
      return # already connected

    @client = new net.Socket
    @stopped = false
    connectPort = atom.config.get("haskell-tools.connect-port")

    @client.connect connectPort, '127.0.0.1', () =>
      console.log('ClientManager: Connected to Haskell Tools')
      @ready = true
      @executeJobs()

    @client.on 'data', (msg) =>
      str = msg.toString()
      if str.match /^\s*$/
        return
      console.log('ClientManager: Received: ' + str)
      data = JSON.parse(str)
      switch data.tag
        when "KeepAliveResponse" then atom.notifications.addInfo 'Server is up and running'
        when "ErrorMessage" then atom.notifications.addError data.errorMsg
        when "LoadedModules" then markerManager.removeAllMarkersFromFiles(data.loadedModules)
        when "CompilationProblem" then markerManager.putErrorMarkers(data.errorMarkers)
        when "ModulesChanged" then # changes automatically detected
        when "Disconnected" then # will reconnect if needed
        else
          atom.notifications.addError 'Internal error: Unrecognized response'
          console.error('Unrecognized response from server: ' + msg)

    @client.on 'close', () =>
      if @stopped
        console.log('ClientManager: Connection closed intentionally.')
        return
      console.log('ClientManager: Connection closed. Reconnecting after 1s')
      @ready = false
      callback = () => @connect()
      setTimeout callback, 1000

  whenReady: (job) ->
    if @ready
      job()
    else @jobs.push(job)

  executeJobs: () ->
    jobsToDo = @jobs
    @jobs = []
    for job in jobsToDo
      job()

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
      @client.write '\n'
    else atom.notifications.addError("Haskell-tools: Server is not ready")

  checkServer: () ->
    @send {"tag":"KeepAlive","contents":[]}

  refactor: (refactoring) ->
    editor = atom.workspace.getActivePaneItem()
    if not editor
      return
    file = editor.buffer.file.path
    range = editor.getSelectedBufferRange()

    if refactoring == 'RenameDefinition' || refactoring == 'ExtractBinding'
      dialog = new NameDialog
      dialog.onSuccess ({answer}) =>
        @performRefactor(refactoring, file, range, [answer.text()])
      dialog.attach()
    else @performRefactor(refactoring, file, range, [])


  performRefactor: (refactoring, file, range, params) ->
    selection = "#{range.start.row + 1}:#{range.start.column + 1}-#{range.end.row + 1}:#{range.end.column + 1}"
    @send { 'tag': 'PerformRefactoring', 'refactoring': refactoring, 'modulePath': file, 'editorSelection': selection, 'details': params }

  addPackages: (packages) ->
    @send { 'tag': 'AddPackages', 'addedPathes': packages }

  removePackages: (packages) ->
    @send { 'tag': 'RemovePackages', 'removedPathes': packages }

  reload: (changed, removed) ->
    @send { 'tag': 'ReLoad', 'changedModules': changed, 'removedModules': removed }
