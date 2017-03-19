{$} = require('atom-space-pen-views')
path = require 'path'
fs = require 'fs'

describe 'Meta test', ->
  [workspaceElement, statusBar, treeView] = []

  beforeEach ->
    workspaceElement = atom.views.getView(atom.workspace)

    waitsForPromise ->
      atom.packages.activatePackage('status-bar').then (pack) ->
        statusBar = workspaceElement.querySelector("status-bar")
    waitsForPromise ->
      atom.packages.activatePackage('tree-view').then (pack) ->
        treeView = workspaceElement.querySelector(".tree-view")

  it 'finds the tree view', ->
    waitsFor -> $(workspaceElement).find('.tree-view').length > 0

  it 'finds the tree view directory header', ->
    path1 = fs.mkdtempSync 'pkg1'
    console.log path1
    atom.project.setPaths([path1])
    waitsFor ->
      $(workspaceElement).find('.tree-view .header').length > 0
