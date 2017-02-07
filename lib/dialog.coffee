{View} = require 'space-pen'

# A base class for our dialogs.
module.exports = class Dialog extends View
  constructor: () ->
    super
    @successCallbacks = []

  attach: () ->
    @panel = atom.workspace.addBottomPanel(item: this.element)
    @answer.focus()
    @answer.getModel().scrollToCursorPosition()
    this.element.addEventListener 'keyup', (event) =>
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
