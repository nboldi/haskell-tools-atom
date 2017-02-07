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
    @done = 0
    @setStatus "Reloading: 0/#{@remaining}"

  loadedData: (mods) ->
    @done += mods.length
    last = mods[mods.length-1] ? ''
    if @done >= @remaining then @setStatus "Ready"
    else @setStatus "Load (#{@done}/#{@remaining}): #{last[1]}"

  setStatus: (text) ->
    @message.text(text)

  deactivate: () ->
    @node.detach()
