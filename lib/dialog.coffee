{View} = require 'space-pen'
{$} = require 'atom-space-pen-views'

# A base class for our dialogs. We use the space-pen implementation.
module.exports = class Dialog extends View
  constructor: () ->
    super
    @successCallbacks = []

  attach: () ->
    $(@element).addClass('ht-dialog')
    @panel = atom.workspace.addBottomPanel(item: @element)
    @answer.focus()
    @answer.getModel().scrollToCursorPosition()
    $(@element).on 'keyup', (event) =>
      if event.key == 'Escape'
        @cancel()
      if event.key == 'Enter'
        @trySubmit()

  close: ->
    panelToDestroy = @panel
    @panel = null
    panelToDestroy?.destroy()
    atom.workspace.getActivePane().activate()

  cancel: ->
    @close()

  showError: (message='') ->
    @errorMessage.text(message)
    @flashError() if message

  trySubmit: () ->
    if @validate()
      @success()
      @close()

  onSuccess: (callback) ->
    @successCallbacks.push(callback)

  success: () ->
    for callback in @successCallbacks
      callback(this)

  validate: () -> true
