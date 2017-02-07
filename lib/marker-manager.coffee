{CompositeDisposable} = require 'atom'
{$} = require('atom-space-pen-views')

module.exports = MarkerManager =
  editors: {}
  markers: []

  # TODO: multiple editors for the same file
  activate: () ->
    @subscriptions = new CompositeDisposable
    # TODO: if editor changes path, marker manager should recognize it
    @subscriptions.add atom.workspace.observeTextEditors (editor) =>
        @editors[editor.buffer.file.path] = editor
        editor.addGutter(name: 'ht-problems', priority: 10, visible: false)
        editor.onDidDestroy () => @editors[editor.buffer.file.path] = null
        @putMarkersOn editor

    # Showing tooltips when hovering over the markers
    # Note: I wanted to show these on
    # TODO: hide all tooltips when one is shown. (Cancel timers as well)
    $('atom-workspace').on 'mouseenter', '.editor .ht-comp-problem', (event) =>
      elem = $(event.target)
      if not elem.hasClass('ht-comp-problem')
        return
      marker = @getMarkerFromElem elem
      child = elem.children('.ht-tooltip')
      if child.length == 0
        elem.append("<div class='ht-tooltip'>#{marker.text}</div>")
        marker.elem = elem.children('.ht-tooltip')
        marker.elem.width(200 + Math.min(200, marker.text.length * 2))
      else
        child.show()
        @keepTooltip elem

    $('atom-workspace').on 'mouseenter', '.editor .ht-comp-problem .ht-tooltip', (event) =>
      @keepTooltip $(event.target).parent()

    $('atom-workspace').on 'mouseout', '.editor .ht-comp-problem', (event) =>
      @hideTooltip $(event.target).closest('.ht-comp-problem')

  hideTooltip: (elem) ->
    marker = @getMarkerFromElem elem
    if marker.timeout then clearTimeout marker.timeout
    hiding = () => marker.elem.hide()
    marker.timeout = setTimeout hiding, 500

  keepTooltip: (elem) ->
    marker = @getMarkerFromElem elem
    if marker.timeout then clearTimeout marker.timeout

  dispose: () ->
    $('atom-workspace').off()
    @subscriptions.dispose()

  getMarkerFromElem: (elem) ->
    @getMarker $(elem).closest('atom-pane').attr('data-active-item-path'), $(elem).index()

  getMarker: (file, index) ->
    if @markers[file] then @markers[file][index] ? {} else {}

  putErrorMarkers: (errorMarkers) ->
    # remove every previous marker
    for [{file},t] in errorMarkers
      if @markers[file]
        @removeAllMarkersFrom file
    for marker in errorMarkers
      @putMarker marker

  putMarker: ([details,text]) ->
    file = details.file
    editor = @editors[file]
    $('.tree-view .icon[data-path]').each (i,elem) =>
      if file.startsWith $(elem).attr('data-path')
        $(elem).addClass 'ht-tree-error'
    if not @markers[file]
      @markers[file] = []
    if editor
      # editor is open
      marker = @putMarkerOn editor, details, text
      @markers[file].push { details: details, text: text, marker: marker }
    else
      # editor is not open
      @markers[file].push { details: details, text: text }

  putMarkersOn: (editor) ->
    allMarkers = @markers[editor.buffer.file.path] ? []
    for marker in allMarkers
      @putMarkerOn editor, marker.details, marker.text

  putMarkerOn: (editor, details, text) ->
    {startRow,startCol,endRow,endCol} = details
    rng = [[startRow - 1, startCol - 1], [endRow - 1, endCol - 1]]
    marker = editor.markBufferRange rng
    editor.decorateMarker(marker, type: 'highlight', class: 'ht-comp-problem')
    gutter = editor.gutterWithName 'ht-problems'
    gutter.show()
    decorator = gutter.decorateMarker(marker, type: 'gutter', class: 'ht-comp-problem')
    marker

  # TODO: clear all markers command in the menu

  removeAllMarkersFromFiles: (files) ->
    console.log files
    $('.tree-view .icon[data-path]').each (i,elem) =>
      if $(elem).attr('data-path') in (files.map ([fn,mn]) -> fn)
        $(elem).removeClass 'ht-tree-error'
    $('.tree-view .header .icon[data-path]').each (i,elem) =>
      # remove markers on folders without errors in files or subfolders
      # depeds on bottom-up traversal
      isThereChild = false
      $(elem).children().each (i,child) =>
        if $(child).hasClass 'ht-tree-error'
          isThereChild = true
      if not isThereChild then $(elem).removeClass 'ht-tree-error'

    for [file,mn] in files
      @removeAllMarkersFrom file

  removeAllMarkersFrom: (file) ->
    for markerReg in @markers[file] ? []
      markerReg.marker?.destroy()
    @markers[file] = []
