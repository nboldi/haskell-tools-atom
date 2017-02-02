{CompositeDisposable} = require 'atom'
{$} = require('atom-space-pen-views')

module.exports = MarkerManager =
  editors: {}
  markers: []
  tooltipsShowing: []

  activate: () ->
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.workspace.observeTextEditors (editor) =>
        @editors[editor.buffer.file.path] = editor
        editor.addGutter(name: 'ht-problems', priority: 10, visible: false)


    $('atom-workspace').on 'mouseenter', '.editor .ht-comp-problem', (event) =>
      elem = $(event.target)
      if not elem.hasClass('ht-comp-problem')
        return
      index = elem.index()
      text = @markers[index]
      child = elem.children('.ht-tooltip')
      if child.length == 0
        elem.append("<div class='ht-tooltip'>#{text}</div>")
        child = elem.children('.ht-tooltip')
        child.width(200 + Math.min(200, text.length * 2))
        @tooltipsShowing[index] = { elem: child, timeout: null }
      else
        child.show()
        @keepTooltip index

    $('atom-workspace').on 'mouseenter', '.editor .ht-comp-problem .ht-tooltip', (event) =>
      @keepTooltip $(event.target).parent().index()

    $('atom-workspace').on 'mouseout', '.editor .ht-comp-problem', (event) =>
      @hideTooltip $(event.target).index()

    $('atom-workspace').on 'mouseout', '.editor .ht-comp-problem .ht-tooltip', (event) =>
      @hideTooltip $(event.target).parent().index()

  hideTooltip: (index) ->
    showing = @tooltipsShowing[index]
    if showing
      if showing.timeout then clearTimeout showing.timeout
      hiding = () => showing.elem.hide()
      showing.timeout = setTimeout(hiding, 500)

  keepTooltip: (index) ->
    showing = @tooltipsShowing[index]
    if showing && showing.timeout then clearTimeout showing.timeout

  dispose: () ->
    $('atom-workspace').off()
    @subscriptions.dispose()

  putErrorMarkers: (errorMarkers) ->
    for [{startRow,startCol,endRow,endCol,file},text] in errorMarkers
      rng = [[startRow - 1, startCol - 1], [endRow - 1, endCol - 1]]
      editor = @editors[file]
      marker = editor.markBufferRange rng
      editor.decorateMarker(marker, type: 'highlight', class: 'ht-comp-problem')
      gutter = editor.gutterWithName 'ht-problems'
      gutter.show()
      decorator = gutter.decorateMarker(marker, type: 'gutter', class: 'ht-comp-problem')
      @markers.push(text)

  removeAllMarkersFrom: (files) ->
    # TODO
