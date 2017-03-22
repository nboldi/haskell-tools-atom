path = require 'path'
fs = require 'fs'
packageHandler = require '../lib/package-manager'
{$} = require 'atom-space-pen-views'

describe 'Haskell tools package manager', ->
  [workspaceElement] = []

  beforeEach ->
    workspaceElement = atom.views.getView(atom.workspace)

    waitsForPromise ->
      atom.packages.activatePackage('tree-view')
    waitsForPromise ->
      jasmine.attachToDOM(workspaceElement)
      atom.packages.activatePackage('haskell-tools')

  describe "@activate()", ->
    it "initially no project is added to the engine", ->
      $ => # Haskell tools depends on a completely loaded dom
        path1 = path.resolve(fs.mkdtempSync 'pkg1-')
        atom.project.setPaths([path1])
        waitsFor -> $('.tree-view .header').length > 0
        runs -> expect($('.tree-view .header')).not.toHaveClass('ht-refactored-header')

  describe "adding a package to the engine", ->
    [path1] = []
    beforeEach ->
      path1 = path.resolve(fs.mkdtempSync 'pkg1-')
      $ => atom.project.setPaths([path1])
    afterEach -> packageHandler.reset()

    it "marks the package in the tree view", ->
      $ => # Haskell tools depends on a completely loaded dom
        $('.tree-view .directory').eq(0).addClass('selected')
        atom.commands.dispatch(workspaceElement, 'haskell-tools:toggle-package')
        expect($('.tree-view .header').eq(0)).toHaveClass('ht-refactored-header')

    it "changes the list of registered packages in the settings", ->
      $ => # Haskell tools depends on a completely loaded dom
        $('.tree-view .directory').eq(0).addClass('selected')
        atom.commands.dispatch(workspaceElement, 'haskell-tools:toggle-package')
        registered = atom.config.get('haskell-tools.refactored-packages')
        expect(registered).toEqual [path1]

    it "notifies the listeners that the packages changed", ->
      $ => # Haskell tools depends on a completely loaded dom
        spy = jasmine.createSpy('package-client-interaction')
        packageHandler.onChange(spy)
        $('.tree-view .directory').eq(0).addClass('selected')
        atom.commands.dispatch(workspaceElement, 'haskell-tools:toggle-package')
        waitsFor ->
          spy.callCount > 0
        runs ->
          changes = packageHandler.getChanges()
          expect(changes.added).toEqual [path1]
          expect(changes.removed).toEqual []

  describe "removing a package from the engine", ->
    path1 = path.resolve(fs.mkdtempSync 'pkg1-')

    beforeEach -> $ => atom.project.setPaths [path1]
    afterEach ->
      packageHandler.reset()
      atom.project.setPaths []

    it "remove the mark from the package in the tree view", ->
      $ => # Haskell tools depends on a completely loaded dom
        $('.tree-view .directory').eq(0).addClass('selected')
        atom.commands.dispatch(workspaceElement, 'haskell-tools:toggle-package')
        atom.commands.dispatch(workspaceElement, 'haskell-tools:toggle-package')
        expect($('.tree-view .header')).not.toHaveClass('ht-refactored-header')

    it "changes the list of registered packages in the settings", ->
      $ => # Haskell tools depends on a completely loaded dom
        $('.tree-view .directory').eq(0).addClass('selected')
        atom.commands.dispatch(workspaceElement, 'haskell-tools:toggle-package')
        atom.commands.dispatch(workspaceElement, 'haskell-tools:toggle-package')
        registered = atom.config.get('haskell-tools.refactored-packages')
        expect(registered).toEqual []

    it "notifies the listeners that the packages changed", ->
      $ => # Haskell tools depends on a completely loaded dom
        spy = jasmine.createSpy('package-client-interaction')
        packageHandler.onChange(spy)
        $('.tree-view .directory').eq(0).addClass('selected')
        atom.commands.dispatch(workspaceElement, 'haskell-tools:toggle-package')
        waitsFor ->
          spy.callCount > 0
        runs ->
          changes = packageHandler.getChanges()
          expect(changes.added).toEqual [path1]
          expect(changes.removed).toEqual []
          atom.commands.dispatch(workspaceElement, 'haskell-tools:toggle-package')
        waitsFor ->
          spy.callCount > 1
        runs ->
          changes = packageHandler.getChanges()
          expect(changes.added).toEqual []
          expect(changes.removed).toEqual [path1]

  describe "adding and then removing a package from the engine", ->
    path1 = path.resolve(fs.mkdtempSync 'pkg1-')

    beforeEach -> $ => atom.project.setPaths [path1]
    afterEach ->
      packageHandler.reset()
      atom.project.setPaths []

    it "does not yield any changes", ->
      $ => # Haskell tools depends on a completely loaded dom
        spy = jasmine.createSpy('package-client-interaction')
        packageHandler.onChange(spy)
        $('.tree-view .directory').eq(0).addClass('selected')
        atom.commands.dispatch(workspaceElement, 'haskell-tools:toggle-package')
        atom.commands.dispatch(workspaceElement, 'haskell-tools:toggle-package')
        waitsFor ->
          spy.callCount > 0
        runs ->
          changes = packageHandler.getChanges()
          expect(changes.added).toEqual []
          expect(changes.removed).toEqual []

  describe "adding a package to the engine", ->
    it "is marked after added to the project", ->
      path1 = path.resolve(fs.mkdtempSync 'pkg1-')
      atom.config.set('haskell-tools.refactored-packages', [path1])
      atom.project.setPaths [path1]
      waitsFor ->
        $('.tree-view .header').length > 0
      runs ->
        expect($('.tree-view .header')).toHaveClass('ht-refactored-header')
