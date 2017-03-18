{$} = require('atom-space-pen-views')

describe 'Haskell tools status bar', ->
  [statusBar, workspaceElement] = []

  beforeEach ->
    workspaceElement = atom.views.getView(atom.workspace)

    waitsForPromise ->
      atom.packages.activatePackage('status-bar').then (pack) ->
        statusBar = workspaceElement.querySelector("status-bar")
    waitsForPromise ->
      atom.packages.activatePackage('tree-view')
    waitsForPromise ->
      jasmine.attachToDOM(workspaceElement)
      atom.packages.activatePackage('haskell-tools')

  describe "@activate()", ->
    it "creates a status bar with text 'Disconnected'", ->
      # Haskell tools depends on a completely loaded dom
      $ => expect($('status-bar .ht-status .ht-message')).toHaveText('Disconnected')
