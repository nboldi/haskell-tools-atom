{$} = require('atom-space-pen-views')
{CompositeDisposable, Emitter} = require 'atom'
logger = require './logger'

# A module for handling the packages that are registered in the Haskell Tools framework.
module.exports = PackageManager =
  subscriptions: null
  packagesRegistered: []
  treeListener: null
  emitter: new Emitter # Generates change packages events for client manager
  updating: false # true, if currently running an update, so config change events are ignored

  activate: () ->
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.commands.add 'atom-workspace',
      'haskell-tools:toggle-package', (event) => @toggleDir(event)

    @subscriptions.add atom.config.onDidChange 'haskell-tools.refactored-packages', (change) => @checkDirs(change)
    @setupListeners()

    $ => @markDirs()
    @subscriptions.add atom.project.onDidChangePaths () =>
      @filterDirs()

  dispose: () ->
    @treeListener.disconnect()
    @subscriptions.dispose()

  # Should be called when the server is restarted
  reconnect: () ->
    @packagesRegistered = []
    @emitter.emit 'change'

  reset: () ->
    @packagesRegistered = []
    atom.config.set('haskell-tools.refactored-packages', [])

  filterDirs: () ->
    packages = atom.config.get('haskell-tools.refactored-packages')
    # Keep only those directories that are in the paths
    for name in packages
      existing = false
      for path in atom.project.getPaths()
        if name.startsWith path
          existing = true
      if !existing
        @setDir name, false

  updateDir: (directoryPath, added) ->
    # update the view
    $('.tree-view .header .icon[data-path="' + directoryPath.replace(/\\/g, "\\\\") + '"]').each (i,elem) =>
      if $(elem).hasClass('ht-refactored') != added
        $(elem).toggleClass 'ht-refactored'
        $(elem).closest('.header').toggleClass('ht-refactored-header')

    pathSegments = directoryPath.split /\\|\//
    directoryName = pathSegments[pathSegments.length-1]
    packages = atom.config.get('haskell-tools.refactored-packages')
    if added then (packages.push(directoryPath) if !(directoryPath in packages)) else packages = packages.filter (d) -> d isnt directoryPath
    atom.config.set('haskell-tools.refactored-packages', packages)
    atom.notifications.addSuccess("The folder " + directoryName + " have been " + (if added then "added to" else "removed from") + " Haskell Tools Refact")

  # Register or unregister the given directory in the Haskell Tools framework. This perform both the registration and the associated view changes.
  setDir: (directoryPath, added) ->
    @updateDir(directoryPath, added)
    @emitter.emit 'change'

  # Reacts to context menu right clicks
  toggleDir: (event) ->
    directoryPathes = []
    # Multiple selected directories can be toggled
    $('.tree-view .directory.selected > .header .icon[data-path]').each (i,elem) =>
      directoryPathes.push $(elem).attr('data-path')
    packages = atom.config.get('haskell-tools.refactored-packages')
    @updating = true
    for directoryPath in directoryPathes
      @updateDir(directoryPath, !(directoryPath in packages))
    @updating = false
    @emitter.emit 'change'

  # When the configuration changes, check which directories should be added/removed
  checkDirs: (change) ->
    return if @updating
    for dir in change.newValue
      if !(dir in change.oldValue) then @setDir(dir, true)
    for dir in change.oldValue
      if !(dir in change.newValue) then @setDir(dir, false)

  # Listen for changes in the list of packages that should be loaded to the engine
  # The listener should call getChanges to get the exact changes
  onChange: (callback) ->
    @emitter.on 'change', callback

  getChanges: () ->
    packages = atom.config.get('haskell-tools.refactored-packages') ? []
    logger.log('Registering packages to Haskell Tools: ' + packages)
    newPackages = packages.filter (x) => not (x in @packagesRegistered)
    removedPackages = @packagesRegistered.filter (x) => not (x in packages)
    @packagesRegistered = packages
    { added: newPackages, removed: removedPackages }

  setupListeners: () ->
    if @treeListener
      @treeListener.disconnect()
    @treeListener = new MutationObserver((mutations) => @markDirs());
    $ =>
      if $('.tree-view')[0]
        @treeListener.observe($('.tree-view')[0], { childList: true, subtree: true })

  # Mark the directories in the tree view, that are added to Haskell Tools with the class .ht-refactored
  markDirs: () ->
    packages = atom.config.get('haskell-tools.refactored-packages')
    $('.tree-view .header .icon[data-path]').each (i,elem) =>
      if $(elem).attr('data-path') in packages
        $(elem).addClass('ht-refactored')
        $(elem).closest('.header').addClass('ht-refactored-header')
