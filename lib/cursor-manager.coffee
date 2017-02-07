{CompositeDisposable} = require 'atom'

# Keeps track of the cursor position between reloads
module.exports = CursorManager =
  subscriptions: new CompositeDisposable
  cursorPos: null

  activate: () ->
    @subscriptions.add atom.workspace.observeTextEditors (editor) =>
      buffer = editor.getBuffer()

      # The event before reload from disk
      @subscriptions.add buffer.onWillReload () =>
        # Sometimes we get these events without content, and that
        # would cause the position to be lost.
        if not buffer.isEmpty()
          @cursorPos = editor.getCursorBufferPosition()

      # The event after reload
      @subscriptions.add editor.getBuffer().onDidReload () =>
        if not buffer.isEmpty()
          editor.setCursorBufferPosition @cursorPos

  dispose: () ->
    @subscriptions.dispose()
