{$} = require('atom-space-pen-views')

# The module responsible for informing the user about the servers status
# using the status bar.
module.exports = StatusBar =
  remaining: 0
  done: 0

  activate: () ->
    $ => # wait for DOM to be ready, and status bar to appear
      context = $('status-bar .status-bar-left')
      @node = $("<div class='inline-block ht-status'>
                  <span class='ht-icon'></span>
                </div>").appendTo context
      @message = $("<span class='ht-message'>Disconnected</span>").appendTo @node

  # When the server is started
  connected: () ->
    @setStatus 'Ready'

  # When the server is stopped
  disconnected: () ->
    @setStatus 'Disconnected'

  # When packages are added display that the server is working on registering them.
  addPackages: () ->
    @setStatus 'Calculating'

  # When a refactoring is performed notify the user that it is being done.
  performRefactoring: () ->
    @setStatus 'Refactoring'

  # When a compilation problem is found, tell the user about it.
  compilationProblem: () ->
    @setStatus 'Ready'

  # Show the user how many modules are needed to be loaded.
  willLoadData: (mods) ->
    @remaining = mods.filter((p) -> not p.endsWith('.hs-boot')).length
    @done = 0
    if @remaining == 0 then @setStatus "Ready"
    else @setStatus "Reloading: 0/#{@remaining}"

  # Inform the user that a given module has been loaded.
  loadedData: (mods) ->
    @done += mods.length
    last = mods[mods.length-1] ? ''
    if @done >= @remaining then @setStatus "Ready"
    else @setStatus "Load (#{@done}/#{@remaining}): #{last[1]}"

  setStatus: (text) ->
    if @message
      @message.text(text)

  dispose: () ->
    if @node then @node.detach()
