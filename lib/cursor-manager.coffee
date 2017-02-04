{CompositeDisposable} = require 'atom'

module.exports = CursorManager =
  subscriptions: new CompositeDisposable
  cursorPos: null

  activate: () ->
    @subscriptions.add atom.workspace.observeTextEditors (editor) =>
      buffer = editor.getBuffer()
      @subscriptions.add buffer.onWillReload () =>
        if not buffer.isEmpty()
          @cursorPos = editor.getCursorBufferPosition()

      @subscriptions.add editor.getBuffer().onDidReload () =>
        if not buffer.isEmpty()
          editor.setCursorBufferPosition @cursorPos

  dispose: () ->
    @subscriptions.dispose()
