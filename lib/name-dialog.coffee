Dialog = require './dialog'
{TextEditorView} = require 'atom-space-pen-views'

module.exports = class RenameDialog extends Dialog
  @content: () ->
    @div =>
      @div 'What should be the new name?'
      @subview 'answer', new TextEditorView(mini: true)
      @div class: 'error-message', outlet: 'errorMessage'

  validate: () ->
    if /^\s+$/.test @answer.text()
      @showError('The new name cannot be empty.')
      false
    else true
