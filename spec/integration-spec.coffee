path = require 'path'
fs = require 'fs'
net = require('net');
{$} = require 'atom-space-pen-views'
clientManager = require '../lib/client-manager'

goodMod = """
module A where
a = 5
"""

refactoredMod = """
module A where
b = 5
"""


describe 'The haskell-tools plugin', ->
  [workspaceElement,sockOn,sockWrite,sockConn,sockDestroy] = []

  beforeEach ->
    workspaceElement = atom.views.getView(atom.workspace)

    # server = net.createServer (socket) =>
    #   console.log 'client connected'
    #   socket.on 'data', data -> console.log
    # server.listen(4123) # default port

    waitsForPromise ->
      atom.packages.activatePackage('status-bar')
    waitsForPromise ->
      atom.packages.activatePackage('tree-view')
    waitsForPromise ->
      jasmine.attachToDOM(workspaceElement)
      atom.packages.activatePackage('haskell-tools')

  it 'should be able to refactor a file', ->
    $ =>
      rootPath = path.resolve(fs.mkdtempSync 'pkg1-')
      escapedPath = rootPath.replace /\\/g, '\\\\'
      atom.project.setPaths [rootPath]
      filePath = path.join(rootPath,'A.hs')
      escapedFilePath = filePath.replace /\\/g, '\\\\'
      fs.writeFileSync(filePath, goodMod)
      waitsForPromise ->
        atom.workspace.open(filePath).then (editor) ->
          editor.setSelectedBufferRange [[1,0],[1,1]]
      runs ->
        # Mock the socket communication in clientManager
        clientManager.createConnection = () -> {
          connect: sockConn = jasmine.createSpy('socket.connect'),
          on: sockOn = jasmine.createSpy('socket.on'),
          write: sockWrite = jasmine.createSpy('socket.write')
          destroy: sockDestroy = jasmine.createSpy('socket.destroy')
        }
        clientManager.connect()
        expect(sockConn).toHaveBeenCalled()
        connCallback = sockConn.calls[sockConn.calls.length - 1].args[2]
        connCallback()
        expect(sockOn).toHaveBeenCalled()
        dataCbs = []
        for {args:[event,callback]} in sockOn.calls
          switch event
            when 'data' then dataCbs.push callback
        atom.project.setPaths [rootPath]
        $('.tree-view .directory').eq(0).addClass('selected')
        atom.commands.dispatch(workspaceElement, 'haskell-tools:toggle-package')
        expect(sockWrite).toHaveBeenCalledWith """{"tag":"AddPackages","addedPathes":["#{escapedPath}"]}"""
        expect($('.ht-message').text()).toBe 'Calculating'
        # Send loading modules message to the client
        for callback in dataCbs
          callback("""{"tag":"LoadingModules","modulesToLoad":["#{escapedFilePath}"]}""")
        expect($('.ht-message').text()).toBe 'Loading (0/1)'
        # Send loaded modules message to the client
        for callback in dataCbs
          callback("""{"tag":"LoadedModules","loadedModules":[["#{escapedFilePath}","A"]]}""")
        expect($('.ht-message').text()).toBe 'Ready'

        expect($('.header.ht-refactored-header').length).toBe 1
        atom.commands.dispatch(workspaceElement, 'haskell-tools:refactor:rename-definition')
        console.log atom.workspace.getTextEditors()
        # fill the name dialog and press enter
        $('atom-text-editor.mini')[0].model.setText('b')
        # $('.ht-dialog hidden-input').text('b')
        expect($('.ht-dialog').length).toBe 1
        e = $.Event('keyup')
        e.key = 'Enter'
        $('.ht-dialog').trigger(e)
        expect($('.ht-dialog').length).toBe 0

        expect(sockWrite).toHaveBeenCalledWith """{"tag":"PerformRefactoring","refactoring":"RenameDefinition","modulePath":"#{escapedFilePath}","editorSelection":"2:1-2:2","details":["b"]}"""
        expect($('.ht-message').text()).toBe 'Refactoring'

        fs.writeFileSync(filePath, refactoredMod)
        # Send loading modules message to the client
        for callback in dataCbs
          callback("""{"tag":"LoadingModules","modulesToLoad":["#{escapedFilePath}"]}""")
        expect($('.ht-message').text()).toBe 'Loading (0/1)'
        # Send loaded modules message to the client
        for callback in dataCbs
          callback("""{"tag":"LoadedModules","loadedModules":[["#{escapedFilePath}","A"]]}""")
        expect($('.ht-message').text()).toBe 'Ready'
