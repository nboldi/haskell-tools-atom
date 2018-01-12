path = require 'path'
fs = require 'fs'
tooltipManager = require '../lib/tooltip-manager'
markerManager = require '../lib/marker-manager'
{$} = require 'atom-space-pen-views'

wrongMod = """
module A where
a = x
b = y
c = z
"""

describe 'The tooltip manager', ->
  [workspaceElement] = []

  beforeEach ->
    workspaceElement = atom.views.getView(atom.workspace)

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
        jasmine.Clock.useMock()
        jasmine.unspy(window, 'setTimeout')
        jasmine.unspy(window, 'clearTimeout')
        atom.workspace.open(filePath)

    it "shows tooltip when the marker is hovered", ->
      $ => # Haskell tools depends on a completely loaded dom
        markerManager.putMarker {location: problem1Loc, message: 'Name not in scope: x', severity: 'Error'}
        $('.decoration.ht-comp-problem').mouseover()
        expect($('.ht-tooltip').length).toBe 1

    it "hides the tooltip after a few seconds of mouseout", ->
      $ => # Haskell tools depends on a completely loaded dom
        markerManager.putMarker {location: problem1Loc, message: 'Name not in scope: x', severity: 'Error'}
        $('.decoration.ht-comp-problem').mouseover()
        $('.decoration.ht-comp-problem').mouseout()
        jasmine.Clock.tick 1500
        expect($('.ht-tooltip')).toHaveClass('invisible')

    it "shows the tooltip again when the marker is hovered", ->
      $ => # Haskell tools depends on a completely loaded dom
        markerManager.putMarker {location: problem1Loc, message: 'Name not in scope: x', severity: 'Error'}
        $('.decoration.ht-comp-problem').mouseover()
        $('.decoration.ht-comp-problem').mouseout()
        jasmine.Clock.tick 500
        $('.decoration.ht-comp-problem').mouseover()
        jasmine.Clock.tick 2000
        expect($('.ht-tooltip')).not.toHaveClass('invisible')

    it "shows the tooltip again when the tooltip is hovered", ->
      $ => # Haskell tools depends on a completely loaded dom
        markerManager.putMarker {location: problem1Loc, message: 'Name not in scope: x', severity: 'Error'}
        $('.decoration.ht-comp-problem').mouseover()
        $('.decoration.ht-comp-problem').mouseout()
        jasmine.Clock.tick 500
        $('.ht-tooltip').mouseover()
        jasmine.Clock.tick 2000
        expect($('.ht-tooltip')).not.toHaveClass('invisible')

    it "hides the tooltip immediately when another is hovered", ->
      $ => # Haskell tools depends on a completely loaded dom
        markerManager.putMarker {location: problem1Loc, message: 'Name not in scope: x', severity: 'Error'}
        markerManager.putMarker {location: problem1Loc, message: 'Name not in scope: x', severity: 'Error'}
        $('.decoration.ht-comp-problem').eq(0).mouseover()
        $('.decoration.ht-comp-problem').eq(1).mouseover()
        expect($('.ht-tooltip').eq(0)).toHaveClass('invisible')
        expect($('.ht-tooltip').eq(1)).not.toHaveClass('invisible')
