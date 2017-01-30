{CompositeDisposable} = require 'atom'

module.exports = HaskellTools =
  subscriptions: null
  treeListener: null

  config:
    'refactored-packages':
      type: 'array'
      default: []
      items:
        type: 'string'

  activate: (state) ->
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.commands.add 'atom-workspace',
      'refactor:rename-definition': => @refactor('RenameDefinition')

    @subscriptions.add atom.commands.add 'atom-workspace',
      'haskell-tools-info': => @info()

    @subscriptions.add atom.commands.add 'atom-workspace',
      'enable-haskell-tools-for-project-folder:toggle', (event) => @toggleDir(event)

    @subscriptions.add atom.config.onDidChange 'haskell-tools.refactored-packages', (change) => @checkDirs(change)
    @markDirs()
    @setupTreeListener()


  deactivate: ->
    @subscriptions.dispose()
    @treeListener.disconnect()

  serialize: ->

  markDirs: () ->
    workspaceElement = atom.views.getView(atom.workspace)
    packages = atom.config.get('haskell-tools.refactored-packages')
    treeElems = workspaceElement.querySelectorAll('.tree-view .project-root-header .icon[data-path]')
    for treeElem in treeElems
      if treeElem.getAttribute('data-path') in packages
        treeElem.classList.add('ht-refactored')

  setDir: (directoryPath, added) ->
    # update the view
    workspaceElement = atom.views.getView(atom.workspace)
    treeElems = workspaceElement.querySelectorAll('.tree-view .project-root-header .icon[data-path="' + directoryPath.replace(/\\/g, "\\\\") + '"]')
    for treeElem in treeElems
      if treeElem.classList.contains('ht-refactored') != added
        treeElem.classList.toggle('ht-refactored')

    pathSegments = directoryPath.split /\\|\//
    directoryName = pathSegments[pathSegments.length-1]
    packages = atom.config.get('haskell-tools.refactored-packages')
    if added then (packages.push(directoryPath) if !(directoryPath in packages)) else packages = packages.filter (d) -> d isnt directoryPath
    atom.config.set('haskell-tools.refactored-packages', packages)
    atom.notifications.addInfo("The folder " + directoryName + " have been " + (if added then "added to" else "removed from") + " Haskell Tools Refact")

  toggleDir: (event) ->
    directoryPath = event.target.getAttribute('data-path')
    packages = atom.config.get('haskell-tools.refactored-packages')
    @setDir(directoryPath, !(directoryPath in packages))

  checkDirs: (change) ->
    for dir in change.newValue
      if !(dir in change.oldValue) then @setDir(dir, true)
    for dir in change.oldValue
      if !(dir in change.newValue) then @setDir(dir, false)

  setupTreeListener: () ->
    @treeListener = new MutationObserver((mutations) => @markDirs());
    treeView = atom.views.getView(atom.workspace).querySelectorAll('.tree-view')[0]
    @treeListener.observe(treeView, { childList: true })

  refactor: (refactoring) ->
    atom.notifications.addInfo("Refactoring: RenameDefinition")

  info: () ->
    atom.notifications.addInfo(atom.project.getPaths())
