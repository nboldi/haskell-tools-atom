{CompositeDisposable, Emitter} = require 'atom'
net = require 'net'
path = require 'path'
fs = require 'fs'
NameDialog = require './name-dialog'
markerManager = require './marker-manager'
tooltipManager = require './tooltip-manager'
logger = require './logger'
statusBar = require './status-bar'
{$} = require('atom-space-pen-views')

# The component that is responsible for maintaining the connection with
# the server.
module.exports = ClientManager =
  subscriptions: new CompositeDisposable
  emitter: new Emitter # generates connect and disconnect events
  client: null # the client socket
  ready: false # true, if the client can send messages to the server
  stopped: true # true, if disconnected from the server by the user
  jobs: [] # tasks to do after the connection has been established
  incomingMsg: '' # the part of the incoming message already received

  serverVersionLowerBound: [1,0,0,0] # inclusive minimum of server version
  serverVersionUpperBound: [1,1,0,0] # exclusive upper limit of server version

  activate: () ->
    statusBar.activate()

    # Register refactoring commands

    @subscriptions.add atom.commands.add 'atom-workspace',
      'haskell-tools:check-server': => @checkServer()

    @subscriptions.add atom.commands.add 'atom-workspace',
      'haskell-tools:query:highlight-extensions', () => @query 'HighlightExtensions'

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

    @subscriptions.add atom.commands.add 'atom-workspace',
      'haskell-tools:refactor:project-organize-imports', () => @refactor 'ProjectOrganizeImports'

    @subscriptions.add atom.commands.add 'atom-workspace',
      'haskell-tools:refactor:organize-extensions', () => @refactor 'OrganizeExtensions'

    @subscriptions.add atom.commands.add 'atom-workspace',
      'haskell-tools:refactor:project-organize-extensions', () => @refactor 'ProjectOrganizeExtensions'

    @subscriptions.add atom.commands.add 'atom-workspace',
      'haskell-tools:undo-refactoring': => @undoRefactoring()

    autoStart = atom.config.get("haskell-tools.start-automatically")

    @emitter.on 'connect', () => @shakeHands()
    @emitter.on 'connect', () => @executeJobs()
    @emitter.on 'connect', () => statusBar.connected()
    @emitter.on 'disconnect', () => statusBar.disconnected()
    @emitter.on 'disconnect', () => markerManager.removeAllMarkers()

    if autoStart
      @connect()

  # Connect to the server. Should not be colled while the connection is alive.
  connect: () ->
    if @ready
      return # already connected

    @client = @createConnection()
    @stopped = false
    connectPort = atom.config.get("haskell-tools.connect-port")

    @client.connect connectPort, '127.0.0.1', () =>
      logger.log('ClientManager: Connected to Haskell Tools')
      @ready = true
      @emitter.emit 'connect'

    @client.on 'data', (msg) =>
      str = @incomingMsg + msg.toString()
      if str.match /^\s*$/
        return
      for msgPart in str.split '\n'
        @handleMsg msgPart

    @client.on 'close', () =>
      @emitter.emit 'disconnect'
      if @stopped
        logger.log('ClientManager: Connection closed intentionally.')
        return
      logger.log('ClientManager: Connection closed. Reconnecting after 1s')
      @ready = false
      callback = () => @connect()
      setTimeout callback, 1000

  createConnection: () ->
    new net.Socket

  # Process an incoming message
  handleMsg: (str) ->
    try
      data = JSON.parse(str)
      if atom.config.get("haskell-tools.debug-mode")
        logger.log('ClientManager: Received: ' + str)
      @incomingMsg = ''
      switch data.tag
        when "KeepAliveResponse" then atom.notifications.addInfo 'Server is up and running'
        when "ErrorMessage"
          atom.notifications.addError data.errorMsg, {dismissable : true}
          statusBar.errorHappened()
        when "LoadedModule"
          markerManager.removeAllMarkersFromFiles [data.loadedModulePath]
          tooltipManager.refresh()
          statusBar.loadedData data.loadedModuleName
        when "QueryResult"
          if data.queryType == "MarkerQuery"
            markerManager.setErrorMarkers(data.queryResult)
            tooltipManager.refresh()
            statusBar.ready()
        when "LoadingModules" then statusBar.willLoadData data.modulesToLoad
        when "CompilationProblem"
          markerManager.setErrorMarkers(data.markers)
          tooltipManager.refresh()
          isError = data.markers.some (e) -> e.severity == "Error"
          if isError
            statusBar.compilationProblem()
        when "Disconnected" then # will reconnect if needed
        when "UnusedFlags" then atom.notifications.addWarning "Error: The following ghc-flags are not recognized: " + data.unusedFlags, {dismissable: true}
        when "HandshakeResponse"
          wrong = false
          arrayLTE = (arr1, arr2) ->
            for i in [0..Math.min(arr1.length,arr2.length)]
              if arr1[i] < arr2[i] then return true
              if arr1[i] > arr2[i] then return false
            return true
          console.log data.serverVersion, @serverVersionLowerBound, @serverVersionUpperBound
          if !arrayLTE(@serverVersionLowerBound, data.serverVersion) && !arrayLTE(data.serverVersion, @serverVersionUpperBound)
            errorMsg = "The server version is not compatible with the client version. For this client the server version must be at >= #{@serverVersionLowerBound} and < #{@serverVersionUpperBound}. You should probably update both the client and the server to the latest versions."
            atom.notifications.addError errorMsg, {dismissable : true}
            logger.error errorMsg
        else
          atom.notifications.addError 'Internal error: Unrecognized response', {dismissable : true}
          logger.error('Unrecognized response from server: ' + msg)
    catch error
      # probably not the whole message is received
      @incomingMsg = str

  # Registers a callback to trigger when the connection is established/restored
  onConnect: (callback) ->
    @emitter.on 'connect', callback

  # Registers a callback to trigger when the connection is lost
  onDisconnect: (callback) ->
    @emitter.on 'disconnect', callback

  # Execute the given job when thes connection is ready
  whenReady: (job) ->
    if @ready
      job()
    else @jobs.push(job)

  # Perform the jobs that are scheduled for execution
  executeJobs: () ->
    jobsToDo = @jobs
    @jobs = []
    for job in jobsToDo
      job()

  dispose: () ->
    @disconnect()
    @subscriptions.dispose()
    statusBar.dispose()

  # Disconnect from the server
  disconnect: () ->
    @ready = false
    @stopped = true
    if @client then @client.destroy()

  # Send a command to the server via JSON
  send: (data) ->
    sentData = JSON.stringify(data)
    if atom.config.get("haskell-tools.debug-mode")
      logger.log('ClientManager: Sending: ' + sentData)
    if @ready
      @client.write sentData
      @client.write '\n'
    else atom.notifications.addError("Haskell-tools: Server is not ready. Start the server first.")

  # These functions send commands to the server on user

  checkServer: () ->
    @send {"tag":"KeepAlive","contents":[]}

  refactor: (refactoring) ->
    editor = atom.workspace.getActivePaneItem()
    if not editor
      return
    if editor.isModified()
      if atom.config.get("haskell-tools.save-before-refactor")
        editor.save()
        disp = editor.onDidSave () =>
                 disp.dispose()
                 tryAgain = () =>
                   @refactor(refactoring) # Try again after saving
                 setTimeout tryAgain, 1000 # wait for the file system to inform Haskell-tools
                                           # about the change.
        return
      else
        atom.notifications.addError("Can't refactor unsaved files. Turn-on auto-saving to enable it.")
        return
    file = editor.buffer.file.path
    range = editor.getSelectedBufferRange()

    if refactoring == 'RenameDefinition' || refactoring == 'ExtractBinding'
      dialog = new NameDialog
      dialog.onSuccess ({answer}) =>
        @performRefactor(refactoring, file, range, [ $(answer).find('.line:not(.dummy)').text()])
      dialog.attach()
    else @performRefactor(refactoring, file, range, [])


  performRefactor: (refactoring, file, range, params) ->
    selection = "#{range.start.row + 1}:#{range.start.column + 1}-#{range.end.row + 1}:#{range.end.column + 1}"
    @send { 'tag': 'PerformRefactoring', 'refactoring': refactoring, 'modulePath': file
          , 'editorSelection': selection, 'details': params, 'shutdownAfter': false
          , 'diffMode': false
          }
    statusBar.performRefactoring()

  query: (queryName) ->
    editor = atom.workspace.getActivePaneItem()
    if not editor
      return
    if editor.isModified()
      if atom.config.get("haskell-tools.save-before-refactor")
        editor.save()
        disp = editor.onDidSave () =>
                 disp.dispose()
                 tryAgain = () =>
                   @query(queryName) # Try again after saving
                 setTimeout tryAgain, 1000 # wait for the file system to inform Haskell-tools
                                           # about the change.
        return
      else
        atom.notifications.addError("Can't query unsaved files. Turn-on auto-saving to enable it.")
        return
    file = editor.buffer.file.path
    range = editor.getSelectedBufferRange()

    @performQuery(queryName, file, range, [])

  performQuery: (query, file, range, params) ->
    selection = "#{range.start.row + 1}:#{range.start.column + 1}-#{range.end.row + 1}:#{range.end.column + 1}"
    @send { 'tag': 'PerformQuery'
          , 'query': query
          , 'modulePath': file
          , 'editorSelection': selection
          , 'details': params
          , 'shutdownAfter': false
          }
    statusBar.performQuery()

  addPackages: (packages) ->
    if packages.length > 0
      @send { 'tag': 'AddPackages', 'addedPathes': packages }
      statusBar.addPackages()

  removePackages: (packages) ->
    if packages.length > 0
      @send { 'tag': 'RemovePackages', 'removedPathes': packages }
      for pkg in packages
        markerManager.removeAllMarkersFromPackage(pkg)

  reload: (added, changed, removed) ->
    if added.length + changed.length + removed.length > 0
      @send { 'tag': 'ReLoad', 'addedModules': added, 'changedModules': changed, 'removedModules': removed }

  shakeHands: () ->
    pluginVersion = atom.packages.getActivePackage('haskell-tools').metadata.version.split '.'
    @send { 'tag': 'Handshake', 'clientVersion': pluginVersion.map (n) -> parseInt(n,10) }

  undoRefactoring: () ->
    editors = atom.workspace.getTextEditors()
    allSaved = editors.every (e) -> !e.isModified()
    if allSaved then @send { 'tag': 'UndoLast', 'contents': [] }
    else atom.notifications.addError("Can't undo refactoring while there are unsaved files. Save or reload them from the disk.")
