path = require 'path'
fs = require 'fs'
os = require 'os'
markerManager = require '../lib/marker-manager'
{$} = require 'atom-space-pen-views'

wrongMod = """
module A where
a = x
b = y
c = z
"""

describe 'Haskell tools marker manager', ->
  [workspaceElement,treeView] = []

  beforeEach ->
    workspaceElement = atom.views.getView(atom.workspace)
    waitsForPromise ->
      atom.packages.activatePackage('tree-view').then (tv) ->
        if tv.mainModule.createView
            treeView = tv.mainModule.createView()
        else
            treeView = tv.mainModule.getTreeViewInstance()
    waitsForPromise ->
      jasmine.attachToDOM(workspaceElement)
      atom.packages.activatePackage('haskell-tools')

  describe 'With the editor already open', ->
    [filePath,problem1Loc,problem2Loc] = []

    beforeEach ->
      waitsForPromise ->
        path1 = path.resolve(fs.mkdtempSync 'pkg1-')
        atom.project.setPaths [path1]
        filePath = path.join(path1,'A.hs')
        fs.writeFileSync(filePath, wrongMod)
        problem1Loc = {file: filePath, startRow: 2, startCol: 5, endRow: 2, endCol: 6}
        problem2Loc = {file: filePath, startRow: 3, startCol: 5, endRow: 3, endCol: 6}
        atom.workspace.open(filePath)

    afterEach ->
      atom.project.setPaths []

    describe "@putMarker()", ->
      it "puts an error marker to the already opened file", ->
        $ => # Haskell tools depends on a completely loaded dom
          markerManager.putMarker {location: problem1Loc, message: 'Name not in scope: x', severity: 'Error'}
          console.log "@putMarker()", $('.decoration.ht-comp-problem').length, $('.overlays .ht-comp-problem').length
          expect($('.decoration.ht-comp-problem').length).toBe 1

    describe "@setErrorMarkers()", ->
      it "removes all existing markers and puts on the new ones", ->
        $ => # Haskell tools depends on a completely loaded dom
          markerManager.putMarker {location: problem1Loc, message: 'Name not in scope: x', severity: 'Error'}
          markerManager.setErrorMarkers [{location: problem2Loc, message: 'Name not in scope: s', severity: 'Error'}]
          expect($('.decoration.ht-comp-problem').length).toBe 1

    describe "@removeAllMarkersFromFiles()", ->
      it "removes all existing markers from the given file", ->
        $ => # Haskell tools depends on a completely loaded dom
          markerManager.putMarker {location: problem1Loc, message: 'Name not in scope: x', severity: 'Error'}
          markerManager.removeAllMarkersFromFiles [filePath]
          expect($('.decoration.ht-comp-problem').length).toBe 0

  describe 'With no open editor', ->
    [filePath,problemLoc] = []

    beforeEach ->
      path1 = path.resolve(fs.mkdtempSync 'pkg1-')
      filePath = path.join(path1,'A.hs')
      fs.writeFileSync(filePath, wrongMod)
      problemLoc = {file: filePath, startRow: 2, startCol: 5, endRow: 2, endCol: 6}

    describe "@putMarker()", ->
      it "puts an error marker that can be seen when the file is opened", ->
        $ => # Haskell tools depends on a completely loaded dom
          markerManager.putMarker {location: problemLoc, message: 'Name not in scope: x', severity: 'Error'}
          expect($('.ht-comp-problem').length).toBe 0

          waitsForPromise ->
            atom.workspace.open(filePath)
          runs ->
            expect($('.decoration.ht-comp-problem').length).toBe 1

  describe 'With a splitted editor', ->
    [editor,problemLoc,filePath] = []

    beforeEach ->
      path1 = path.resolve(fs.mkdtempSync 'pkg1-')
      atom.project.setPaths [path1]
      filePath = path.join(path1,'A.hs')
      fs.writeFileSync(filePath, wrongMod)
      problemLoc = {file: filePath, startRow: 2, startCol: 5, endRow: 2, endCol: 6}
      waitsForPromise ->
        atom.workspace.open(filePath).then (edit) -> atom.views.getView(edit).focus()

    describe '@putMarker()', ->
      it 'puts a marker on each pane', ->
        $ => # Haskell tools depends on a completely loaded dom
          atom.commands.dispatch(atom.views.getView(atom.workspace.getActivePane()), 'pane:split-right-and-copy-active-item')
          expect($('.editor').length).toBe 2
          markerManager.putMarker {location: problemLoc, message: 'Name not in scope: x', severity: 'Error'}
          expect($('.decoration.ht-comp-problem').length).toBe 2

    describe "@removeAllMarkersFromFiles()", ->
      it "removes all existing markers from all panes", ->
        $ => # Haskell tools depends on a completely loaded dom
          markerManager.putMarker {location: problemLoc, message: 'Name not in scope: x', severity: 'Error'}
          markerManager.removeAllMarkersFromFiles [filePath]
          expect($('.decoration.ht-comp-problem').length).toBe 0

  describe 'In the tree view', ->
    [filePath,rootPath,problemLoc,editor,shownItems] = []

    beforeEach ->
      rootPath = path.resolve(fs.mkdtempSync 'pkg1-')
      atom.project.setPaths [rootPath]
      filePath = path.join(rootPath,'A.hs')
      fs.writeFileSync(filePath, wrongMod)
      problemLoc = {file: filePath, startRow: 2, startCol: 5, endRow: 2, endCol: 6}

    afterEach ->
      atom.project.setPaths []

    describe "@putMarker()", ->
      it "puts the error marker on opened folders and files", ->
        waitsForPromise ->
          atom.workspace.open(filePath)
        runs ->
          expect($('.ht-tree-error').length).toBe 0
          markerManager.putMarker {location: problemLoc, message: 'Name not in scope: x', severity: 'Error'}
          shownItems = $('.tree-view .icon').length
          expect($('.ht-tree-error').length).toBe shownItems # should be 2

    describe "@putMarker()", ->
      it "puts the error marker on opened folders and files, even if the tree view cannot be seen", ->
        waitsForPromise ->
          atom.workspace.open(filePath)
        runs ->
          atom.commands.dispatch(workspaceElement, 'tree-view:toggle')
          markerManager.putMarker {location: problemLoc, message: 'Name not in scope: x', severity: 'Error'}
          atom.commands.dispatch(workspaceElement, 'tree-view:toggle')
          shownItems = $('.tree-view .icon').length
          expect($('.ht-tree-error').length).toBe shownItems # should be 2

    describe "@putMarker()", ->
      it "puts the error marker on hidden folders and files", ->
        waitsForPromise ->
          expect($('.ht-tree-error').length).toBe 0
          markerManager.putMarker {location: problemLoc, message: 'Name not in scope: x', severity: 'Error'}
          atom.workspace.open(filePath)
        runs ->
          shownItems = $('.tree-view .icon').length
          expect($('.ht-tree-error').length).toBe shownItems # should be 2

    describe "@removeAllMarkersFromFiles()", ->
      it "remove markers from the tree view", ->
        waitsForPromise ->
          atom.workspace.open filePath
        runs ->
          markerManager.putMarker {location: problemLoc, message: 'Name not in scope: x', severity: 'Error'}
          shownItems = $('.tree-view .icon').length
          expect($('.ht-tree-error').length).toBe shownItems # should be 2
          markerManager.removeAllMarkersFromFiles [filePath]
          expect($('.ht-tree-error').length).toBe 0

    describe "@removeAllMarkersFromFiles()", ->
      it "does not remove the markers from the tree view while any file is marked", ->
        filePath2 = path.join(rootPath,'B.hs')
        fs.writeFileSync(filePath2, wrongMod)
        problem2Loc = {file: filePath2, startRow: 2, startCol: 5, endRow: 2, endCol: 6}
        waitsForPromise ->
          atom.workspace.open(filePath).then (edit) ->
            atom.workspace.open filePath2
        runs ->
          expect($('.tree-view .icon').length).toBe 3
          markerManager.putMarker {location: problemLoc, message: 'Name not in scope: x', severity: 'Error'}
          markerManager.putMarker {location: problem2Loc, message: 'Name not in scope: x', severity: 'Error'}
          expect($('.ht-tree-error').length).toBe 3
          markerManager.removeAllMarkersFromFiles [filePath]
          expect($('.ht-tree-error').length).toBe 2
          markerManager.removeAllMarkersFromFiles [filePath2]
          expect($('.ht-tree-error').length).toBe 0
