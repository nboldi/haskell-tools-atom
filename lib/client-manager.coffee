{$,jQuery} = require('atom-space-pen-views')
{CompositeDisposable} = require 'atom'
net = require 'net'
NameDialog = require './name-dialog'

module.exports = ClientManager =
  subscriptions: null
  client: null
  ready: false
  stopped: true
  jobs: []
  editors: {}
  markers: []
  tooltipsShowing: []

  activate: () ->
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.commands.add 'atom-workspace',
      'haskell-tools:check-server': => @checkServer()

    @subscriptions.add atom.workspace.observeTextEditors (editor) =>
      @editors[editor.buffer.file.path] = editor
      editor.addGutter(name: 'ht-problems', priority: 10, visible: false)
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

    $('atom-workspace').on 'mouseenter', '.editor .ht-comp-problem', (event) =>
      elem = $(event.target)
      if not elem.hasClass('ht-comp-problem')
        return
      index = elem.index()
      console.log 'enter', index
      text = @markers[index]
      child = elem.children('.ht-tooltip')
      if child.length == 0
        elem.append("<div class='ht-tooltip'>#{text}</div>")
        child = elem.children('.ht-tooltip')
        child.width(200 + Math.min(200, text.length * 2))
        @tooltipsShowing[index] = { elem: child, timeout: null }
      else
        child.show()
        if @tooltipsShowing[index].timeout then clearTimeout @tooltipsShowing[index].timeout

    $('atom-workspace').on 'mouseout', '.editor .ht-comp-problem', (event) =>
      showing = @tooltipsShowing[$(event.target).index()]
      console.log 'out', $(event.target).index()
      if showing
        if showing.timeout then clearTimeout showing.timeout
        hiding = () => showing.elem.hide()
        showing.timeout = setTimeout(hiding, 500)

    $('atom-workspace').on 'mouseout', '.editor .ht-comp-problem .ht-tooltip', (event) =>
      showing = @tooltipsShowing[$(event.target).parent().index()]
      console.log 'tt out', $(event.target).parent().index()
      if showing
        if showing.timeout then clearTimeout showing.timeout
        hiding = () => showing.elem.hide()
        showing.timeout = setTimeout(hiding, 500)

    $('atom-workspace').on 'mouseover', '.editor .ht-comp-problem .ht-tooltip', (event) =>
      showing = @tooltipsShowing[$(event.target).parent().index()]
      console.log 'tt enter', $(event.target).parent().index()
      if showing && showing.timeout then clearTimeout showing.timeout

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
      console.log('ClientManager: Received: ' + msg)
      data = JSON.parse(msg)
      switch data.tag
        when "KeepAliveResponse" then atom.notifications.addInfo 'Server is up and running'
        when "ErrorMessage" then atom.notifications.addError data.errorMsg
        when "LoadedModules" then # TODO: readyness
        when "CompilationProblem" then @putErrorMarkers(data.errorMarkers)
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

  putErrorMarkers: (errorMarkers) ->
    for [{startRow,startCol,endRow,endCol,file},text] in errorMarkers
      rng = [[startRow - 1, startCol - 1], [endRow - 1, endCol - 1]]
      editor = @editors[file]
      marker = editor.markBufferRange rng
      editor.decorateMarker(marker, type: 'highlight', class: 'ht-comp-problem')
      gutter = editor.gutterWithName 'ht-problems'
      gutter.show()
      decorator = gutter.decorateMarker(marker, type: 'gutter', class: 'ht-comp-problem')
      @markers.push(text)

      # callback = () -> console.log $('.editor .ht-comp-problem')
      # setTimeout callback, 1000
