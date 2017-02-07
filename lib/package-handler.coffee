{$} = require('atom-space-pen-views')
{CompositeDisposable} = require 'atom'
clientManager = require './client-manager'
logger = require './logger'

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
    packages = atom.config.get('haskell-tools.refactored-packages')
    $('.tree-view .header .icon[data-path]').each (i,elem) =>
      if $(elem).attr('data-path') in packages
        $(elem).addClass('ht-refactored')

  # Register or unregister the given directory in the Haskell Tools framework. This perform both the registration and the associated view changes.
  setDir: (directoryPath, added) ->
    # update the view
    $('.tree-view .header .icon[data-path="' + directoryPath.replace(/\\/g, "\\\\") + '"]').each (i,elem) =>
      if $(elem).hasClass('ht-refactored') != added
        $(elem).toggleClass 'ht-refactored'

    pathSegments = directoryPath.split /\\|\//
    directoryName = pathSegments[pathSegments.length-1]
    packages = atom.config.get('haskell-tools.refactored-packages')
    if added then (packages.push(directoryPath) if !(directoryPath in packages)) else packages = packages.filter (d) -> d isnt directoryPath
    atom.config.set('haskell-tools.refactored-packages', packages)
    atom.notifications.addInfo("The folder " + directoryName + " have been " + (if added then "added to" else "removed from") + " Haskell Tools Refact")
    clientManager.whenReady () => @updateRegisteredPackages()

  # Reacts to context menu right clicks
  toggleDir: (event) ->
    directoryPathes = []
    # Multiple selected directories can be toggled
    $('.tree-view .directory.selected > .header .icon[data-path]').each (i,elem) =>
      directoryPathes.push $(elem).attr('data-path')
    packages = atom.config.get('haskell-tools.refactored-packages')
    for directoryPath in directoryPathes
      @setDir(directoryPath, !(directoryPath in packages))

  # When the configuration changes, check which directories should be added/removed
  checkDirs: (change) ->
    for dir in change.newValue
      if !(dir in change.oldValue) then @setDir(dir, true)
    for dir in change.oldValue
      if !(dir in change.newValue) then @setDir(dir, false)

  # I found no way to listen to packages added to the tree view, so instead we
  # react to the tree view being changed. But because the tree view might not
  # be present, we have to listen for changes in the dom.
  # Unfortunately this is not possible with jquery.

  setupListeners: () ->
    # if the tree view is active, mark the selected packages
    @markDirs()
    # otherwise wait for the treeview to appear and then mark the packages
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
    logger.log('Registering packages to Haskell Tools: ' + packages)
    newPackages = packages.filter (x) => not (x in @packagesRegistered)
    removedPackages = @packagesRegistered.filter (x) => not (x in packages)

    clientManager.addPackages(newPackages) if newPackages.length > 0
    clientManager.removePackages(removedPackages) if removedPackages.length > 0
    @packagesRegistered = packages
