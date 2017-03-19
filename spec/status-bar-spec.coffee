{$} = require('atom-space-pen-views')
statusBar = require '../lib/status-bar'

describe 'Haskell tools status bar', ->
  [workspaceElement] = []

  beforeEach ->
    workspaceElement = atom.views.getView(atom.workspace)

    waitsForPromise ->
      atom.packages.activatePackage('status-bar')
    waitsForPromise ->
      atom.packages.activatePackage('tree-view')
    waitsForPromise ->
      jasmine.attachToDOM(workspaceElement)
      atom.packages.activatePackage('haskell-tools')

  describe "@activate()", ->
    it "creates a status bar with text 'Disconnected'", ->
      # Haskell tools depends on a completely loaded dom
      $ => expect($('status-bar .ht-status .ht-message')).toHaveText('Disconnected')

  describe "addPackages()", ->
    it "sets the status bar message to 'Calculating'", ->
      # Haskell tools depends on a completely loaded dom
      $ =>
        statusBar.addPackages()
        expect($('status-bar .ht-status .ht-message')).toHaveText('Calculating')

  describe "willLoadData()", ->
    it "counts the remaining packages", ->
      # Haskell tools depends on a completely loaded dom
      $ =>
        statusBar.willLoadData ['A.hs','B.hs','C.hs','B.hs-boot']
        expect($('status-bar .ht-status .ht-message')).toHaveText('Loading (0/3)')
        statusBar.loadedData [['A.hs','A']]
        expect($('status-bar .ht-status .ht-message')).toHaveText('Loading (1/3): A')
        statusBar.loadedData [['B.hs','B']]
        expect($('status-bar .ht-status .ht-message')).toHaveText('Loading (2/3): B')
        statusBar.loadedData [['C.hs','C']]
        expect($('status-bar .ht-status .ht-message')).toHaveText('Ready')
