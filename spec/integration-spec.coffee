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
  [workspaceElement,rootPath,sockOn,sockWrite,sockConn,sockDestroy,filePath,escapedPath,escapedFilePath] = []

  beforeEach ->
    workspaceElement = atom.views.getView(atom.workspace)

    waitsForPromise ->
      atom.packages.activatePackage('status-bar')
    waitsForPromise ->
      atom.packages.activatePackage('tree-view')
    waitsForPromise ->
      jasmine.attachToDOM(workspaceElement)
      atom.packages.activatePackage('haskell-tools').then () ->
        # Mock the socket communication in clientManager
        clientManager.createConnection = () -> {
          connect: sockConn = jasmine.createSpy('socket.connect'),
          on: sockOn = jasmine.createSpy('socket.on'),
          write: sockWrite = jasmine.createSpy('socket.write')
          destroy: sockDestroy = jasmine.createSpy('socket.destroy')
        }
    rootPath = path.resolve(fs.mkdtempSync 'pkg1-')
    escapedPath = rootPath.replace /\\/g, '\\\\'
    atom.project.setPaths [rootPath]
    filePath = path.join(rootPath,'A.hs')
    escapedFilePath = filePath.replace /\\/g, '\\\\'
    fs.writeFileSync(filePath, goodMod)
    waitsForPromise ->
      atom.workspace.open(filePath).then (editor) ->
        editor.setSelectedBufferRange [[1,0],[1,1]]

  it 'should be able to refactor a file', ->
    $ =>
      clientManager.connect()
      expect(sockConn).toHaveBeenCalled()
      mockReceive = mockConnection(sockConn, sockOn)
      expect(sockOn).toHaveBeenCalled()
      atom.project.setPaths [rootPath]
      # handshake
      expect(sockWrite).toHaveBeenCalled
      expect(sockWrite.calls.some (s) -> s.args[0].indexOf("Handshake") != (-1)).toBe true
      mockReceive("""{"tag":"HandshakeResponse","serverVersion":[0,8,0,0]}""")
      # add package to haskell tools
      $('.tree-view .directory').eq(0).addClass('selected')
      atom.commands.dispatch(workspaceElement, 'haskell-tools:toggle-package')
      expect(sockWrite).toHaveBeenCalledWith """{"tag":"AddPackages","addedPathes":["#{escapedPath}"]}"""
      expect($('.ht-message').text()).toBe 'Calculating'
      # Send loading modules message to the client
      mockReceive("""{"tag":"LoadingModules","modulesToLoad":["#{escapedFilePath}"]}""")
      expect($('.ht-message').text()).toBe 'Loading (0/1)'
      # Send loaded modules message to the client
      mockReceive("""{"tag":"LoadedModules","loadedModules":[["#{escapedFilePath}","A"]]}""")
      expect($('.ht-message').text()).toBe 'Ready'

      expect($('.header.ht-refactored-header').length).toBe 1
      atom.commands.dispatch(workspaceElement, 'haskell-tools:refactor:rename-definition')
      # fill the name dialog and press enter
      $('atom-text-editor.mini').find('.line:not(.dummy)').text('b')
      # $('.ht-dialog hidden-input').text('b')
      expect($('.ht-dialog').length).toBe 1
      pressEnter $('.ht-dialog')
      expect($('.ht-dialog').length).toBe 0

      expect(sockWrite).toHaveBeenCalledWith """{"tag":"PerformRefactoring","refactoring":"RenameDefinition","modulePath":"#{escapedFilePath}","editorSelection":"2:1-2:2","details":["b"]}"""
      expect($('.ht-message').text()).toBe 'Refactoring'

      fs.writeFileSync(filePath, refactoredMod)
      # Send loading modules message to the client
      mockReceive("""{"tag":"LoadingModules","modulesToLoad":["#{escapedFilePath}"]}""")
      expect($('.ht-message').text()).toBe 'Loading (0/1)'
      # Send loaded modules message to the client
      mockReceive("""{"tag":"LoadedModules","loadedModules":[["#{escapedFilePath}","A"]]}""")
      expect($('.ht-message').text()).toBe 'Ready'

  it 'should be able to handle move operation', ->
    $ =>
      clientManager.connect()
      mockReceive = mockConnection(sockConn, sockOn)
      $('.icon[data-path]').each (i,elem) =>
        if $(elem).attr('data-path') == filePath
          atom.commands.dispatch(elem, 'tree-view:move')
          editorElem = $('.tree-view-dialog atom-text-editor').find('.line:not(.dummy)').text('B.hs')
          atom.commands.dispatch($('.tree-view-dialog atom-text-editor')[0], 'core:confirm')
      escapedNewFilePath = path.join(rootPath,'B.hs').replace /\\/g, '\\\\'
      expect(sockWrite).toHaveBeenCalledWith """{"tag":"ReLoad","addedModules":["#{escapedNewFilePath}"],"changedModules":[],"removedModules":["#{escapedFilePath}"]}"""

  # remove cannot be tested because of the modal popup, with duplicate there
  # is a problem about watching for the file to exist

pressEnter = (elem) ->
  e = $.Event('keyup')
  e.key = 'Enter'
  elem.trigger(e)

mockConnection = (connMock, onMock) ->
  connCallback = connMock.calls[connMock.calls.length - 1].args[2]
  connCallback()
  dataCallbacks = []
  for {args:[event,callback]} in onMock.calls
    switch event
      when 'data' then dataCallbacks.push callback
  (msg) =>
    for callback in dataCallbacks
      callback(msg)
