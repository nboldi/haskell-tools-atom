{CompositeDisposable} = require 'atom'
clientManager = require './client-manager'

# A module for handling the packages that are registered in the Haskell Tools framework.
module.exports = PackageHandler =
  subscriptions: null
  treeListener: null
  packagesRegistered: []

  activate: () ->
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.commands.add 'atom-workspace',
      'haskell-tools:toggle-package', (event) => @toggleDir(event)

    @subscriptions.add atom.config.onDidChange 'haskell-tools.refactored-packages', (change) => @checkDirs(change)

    clientManager.onConnect () =>
      @packagesRegistered = []
      @updateRegisteredPackages()
    @setupListeners()

  dispose: () ->
    @treeListener.disconnect()
    @subscriptions.dispose()

  # Mark the directories in the tree view, that are added to Haskell Tools with the class .ht-refactored
  markDirs: () ->
    workspaceElement = atom.views.getView(atom.workspace)
    packages = atom.config.get('haskell-tools.refactored-packages')
    treeElems = workspaceElement.querySelectorAll('.tree-view .project-root-header .icon[data-path]')
    for treeElem in treeElems
      if treeElem.getAttribute('data-path') in packages
        treeElem.classList.add('ht-refactored')

  # Register or unregister the given directory in the Haskell Tools framework. This perform both the registration and the associated view changes.
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
    clientManager.whenReady () => @updateRegisteredPackages()

  toggleDir: (event) ->
    directoryPath = event.target.getAttribute('data-path')
    packages = atom.config.get('haskell-tools.refactored-packages')
    @setDir(directoryPath, !(directoryPath in packages))

  checkDirs: (change) ->
    for dir in change.newValue
      if !(dir in change.oldValue) then @setDir(dir, true)
    for dir in change.oldValue
      if !(dir in change.newValue) then @setDir(dir, false)

  setupListeners: () ->
    # if the tree view is active, mark the selected packages
    @markDirs()
    # otherwise wait for the treeview to appear and then mark the packages
    # TODO: simplify with jQuery
    @treeListener = new MutationObserver((mutations) => @markDirs(); @setupTreeListener());
    panelContainers = atom.views.getView(atom.workspace).querySelectorAll('atom-panel-container')
    for panelCont in panelContainers
      @treeListener.observe(panelCont, { childList: true })

  setupTreeListener: () ->
    treeView = atom.views.getView(atom.workspace).querySelectorAll('.tree-view')
    if treeView.length > 0
      @treeListener.observe(treeView[0], { childList: true })

  updateRegisteredPackages: () ->
    packages = atom.config.get('haskell-tools.refactored-packages') ? []
    console.log('Registering packages to Haskell Tools: ' + packages)
    newPackages = packages.filter (x) => not (x in @packagesRegistered)
    removedPackages = @packagesRegistered.filter (x) => not (x in packages)

    clientManager.addPackages(newPackages) if newPackages.length > 0
    clientManager.removePackages(removedPackages) if removedPackages.length > 0
    @packagesRegistered = packages
