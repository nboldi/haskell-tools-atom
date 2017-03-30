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
  [workspaceElement] = []

  beforeEach ->
    workspaceElement = atom.views.getView(atom.workspace)
    waitsForPromise ->
      atom.packages.activatePackage('tree-view')
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
          markerManager.putMarker [problem1Loc, 'Name not in scope: x']
          expect($('.decoration.ht-comp-problem').length).toBe 1
          expect($('.highlight.ht-comp-problem').length).toBe 1

    describe "@setErrorMarkers()", ->
      it "removes all existing markers and puts on the new ones", ->
        $ => # Haskell tools depends on a completely loaded dom
          markerManager.putMarker [problem1Loc, 'Name not in scope: x']
          markerManager.setErrorMarkers [[problem2Loc, 'Name not in scope: y']]
          expect($('.decoration.ht-comp-problem').length).toBe 1
          expect($('.highlight.ht-comp-problem').length).toBe 1

    describe "@removeAllMarkersFromFiles()", ->
      it "removes all existing markers from the given file", ->
        $ => # Haskell tools depends on a completely loaded dom
          markerManager.putMarker [problem1Loc, 'Name not in scope: x']
          markerManager.removeAllMarkersFromFiles [filePath]
          expect($('.decoration.ht-comp-problem').length).toBe 0
          expect($('.highlight.ht-comp-problem').length).toBe 0

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
          markerManager.putMarker [problemLoc, 'Name not in scope: x']
          expect($('.ht-comp-problem').length).toBe 0

          waitsForPromise ->
            atom.workspace.open(filePath)
          runs ->
            expect($('.decoration.ht-comp-problem').length).toBe 1
            expect($('.highlight.ht-comp-problem').length).toBe 1

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
          markerManager.putMarker [problemLoc, 'Name not in scope: x']
          expect($('.decoration.ht-comp-problem').length).toBe 2
          expect($('.highlight.ht-comp-problem').length).toBe 2

    describe "@removeAllMarkersFromFiles()", ->
      it "removes all existing markers from all panes", ->
        $ => # Haskell tools depends on a completely loaded dom
          markerManager.putMarker [problemLoc, 'Name not in scope: x']
          markerManager.removeAllMarkersFromFiles [filePath]
          expect($('.decoration.ht-comp-problem').length).toBe 0
          expect($('.highlight.ht-comp-problem').length).toBe 0

  describe 'In the tree view', ->
    [filePath,rootPath,problemLoc,editor] = []

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
          atom.workspace.open(filePath).then (edit) ->
            atom.commands.dispatch(atom.views.getView(edit), 'tree-view:reveal-active-file')
        runs ->
          expect($('.ht-tree-error').length).toBe 0
          expect($('.icon').length).toBe 2
          markerManager.putMarker [problemLoc, 'Name not in scope: x']
          expect($('.ht-tree-error').length).toBe 2

    describe "@putMarker()", ->
      it "puts the error marker on opened folders and files, even if the tree view cannot be seen", ->
        waitsForPromise ->
          atom.workspace.open(filePath).then (edit) ->
            atom.commands.dispatch(atom.views.getView(edit), 'tree-view:reveal-active-file')
        runs ->
          atom.commands.dispatch(workspaceElement, 'tree-view:toggle')
          expect($('.icon').length).toBe 0
          markerManager.putMarker [problemLoc, 'Name not in scope: x']
          atom.commands.dispatch(workspaceElement, 'tree-view:toggle')
          expect($('.icon').length).toBe 2
          expect($('.ht-tree-error').length).toBe 2

    describe "@putMarker()", ->
      it "puts the error marker on hidden folders and files", ->
        waitsForPromise ->
          expect($('.ht-tree-error').length).toBe 0
          markerManager.putMarker [problemLoc, 'Name not in scope: x']
          atom.workspace.open(filePath).then (edit) ->
            atom.commands.dispatch(atom.views.getView(edit), 'tree-view:reveal-active-file')
        runs ->
          expect($('.icon').length).toBe 2
          expect($('.ht-tree-error').length).toBe 2

    describe "@removeAllMarkersFromFiles()", ->
      it "remove markers from the tree view", ->
        waitsForPromise ->
          atom.workspace.open filePath
        runs ->
          markerManager.putMarker [problemLoc, 'Name not in scope: x']
          expect($('.ht-tree-error').length).toBe 2
          markerManager.removeAllMarkersFromFiles [filePath]
          expect($('.ht-tree-error').length).toBe 0

    describe "@removeAllMarkersFromFiles()", ->
      it "does not remove the markers from the tree view while any file is marked", ->
        filePath2 = path.join(rootPath,'B.hs')
        fs.writeFileSync(filePath2, wrongMod)
        problem2Loc = {file: filePath2, startRow: 2, startCol: 5, endRow: 2, endCol: 6}
        waitsForPromise ->
          atom.workspace.open filePath
        waitsForPromise ->
          atom.workspace.open filePath2
        runs ->
          markerManager.putMarker [problemLoc, 'Name not in scope: x']
          markerManager.putMarker [problem2Loc, 'Name not in scope: x']
          expect($('.ht-tree-error').length).toBe 3
          markerManager.removeAllMarkersFromFiles [filePath]
          expect($('.ht-tree-error').length).toBe 2
          markerManager.removeAllMarkersFromFiles [filePath2]
          expect($('.ht-tree-error').length).toBe 0
