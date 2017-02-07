{$} = require('atom-space-pen-views')

module.exports = StatusBar =
  remaining: 0
  done: 0

  activate: () ->
    context = $('status-bar .status-bar-left')
    @node = $("<div class='inline-block ht-status'>
                <span class='ht-icon'></span>
              </div>").appendTo context
    @message = $("<span class='ht-message'>Starting</span>").appendTo @node

  addPackages: () ->
    @setStatus 'Calculating'

  performRefactoring: () ->
    @setStatus 'Refactoring'

  compilationProblem: () ->
    @setStatus 'Compilation problem'

  willLoadData: (mods) ->
    @remaining = mods.length
    @setStatus "Reloading: 0/#{@remaining}"

  loadedData: (mods) ->
    @done += mods.length
    if @done >= @remaining then @setStatus "Ready"
    else @setStatus "Reloading: #{@done}/#{@remaining}"

  setStatus: (text) ->
    @message.text(text)

  deactivate: () ->
    @node.detach()
