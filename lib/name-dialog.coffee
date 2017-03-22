Dialog = require './dialog'
{TextEditorView} = require 'atom-space-pen-views'

# A dialog for getting a name for renaming or a new binding
module.exports = class RenameDialog extends Dialog
  @content: () ->
    @div =>
      @subview 'answer', new TextEditorView(mini: true, placeholderText: 'The new name of the element')
      @div class: 'error-message', outlet: 'errorMessage'

  validate: () ->
    if /^\s+$/.test @answer.text()
      @showError('The new name cannot be empty.')
      false
    else true
