{CompositeDisposable} = require 'atom'
{$} = require('atom-space-pen-views')

# Controls how error markers are registered and displayed when there are compilation
# problems in the source files
module.exports = MarkerManager =
  editors: {} # We store the editors associated with the given files. We use
              # the editor object for putting up markers.
  markers: {} # We store the created markers for each file. Inside the file we
              # identify markers using their index in the list of all markers.
  treeListener: null

  activate: () ->
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.workspace.observeTextEditors (editor) =>
      if editor.buffer.file
        if @editors[editor.buffer.file.path]
          @editors[editor.buffer.file.path].push editor
        else @editors[editor.buffer.file.path] = [editor]
        editor.addGutter(name: 'ht-problems', priority: 10, visible: false)
        editor.onDidDestroy () =>
          if @editors[editor.buffer.file.path]
            editorIndex = @editors[editor.buffer.file.path].indexOf editor
            @editors[editor.buffer.file.path].splice editorIndex, 1
        @putMarkersOn editor
    @setupListeners()
    atom.commands.onDidDispatch (event) =>
      if event.type == 'tree-view:toggle'
        @setupListeners()
        @refreshFileMarkers()

  dispose: () ->
    @removeAllMarkers()
    @treeListener.disconnect()
    @subscriptions.dispose()

  # Gets the marker for a given marker based on the containing editor and the
  # position of the marker inside the file.
  getMarkerFromElem: (elem) ->
    @getMarker $(elem).closest('atom-pane').attr('data-active-item-path'), $(elem).index()

  # Get the nth marker in a given file.
  getMarker: (file, index) ->
    if @markers[file] then @markers[file][index] ? {} else {}

  # Register the given error markers and remove already existing
  setErrorMarkers: (errorMarkers) ->
    # remove every previous marker
    for [{file},t] in errorMarkers
      if @markers[file]
        @removeAllMarkersFromFiles [file]
    for marker in errorMarkers
      @putMarker marker

  # Registers the given error marker, shows if possible
  putMarker: ([details,text]) ->
    file = details.file
    editorsFor = @editors[file]
    $('.tree-view .icon[data-path]').each (i,elem) =>
      if file.startsWith $(elem).attr('data-path')
        $(elem).addClass 'ht-tree-error'
    if not @markers[file]
      @markers[file] = []
    if editorsFor
      markers = []
      for editor in editorsFor
        markers.push @putMarkerOn(editor, details, text)
      @markers[file].push { details: details, text: text, markers: markers }
    else
      # editor is not open
      @markers[file].push { details: details, text: text, markers: [] }

  # Show registered error markers on the given editor.
  putMarkersOn: (editor) ->
    allMarkers = @markers[editor.buffer.file.path] ? []
    for marker in allMarkers
      marker.markers.push @putMarkerOn(editor, marker.details, marker.text)

  # Shows the given error marker on a given editor
  putMarkerOn: (editor, details, text) ->
    {startRow,startCol,endRow,endCol} = details
    rng = [[startRow - 1, startCol - 1], [endRow - 1, endCol - 1]]
    marker = editor.markBufferRange rng
    editor.decorateMarker(marker, type: 'highlight', class: 'ht-comp-problem')
    gutter = editor.gutterWithName 'ht-problems'
    gutter.show()
    decorator = gutter.decorateMarker(marker, type: 'gutter', class: 'ht-comp-problem')
    marker

  # Remove all markers in the entire workspace
  removeAllMarkers: () ->
    $('.tree-view .ht-tree-error').removeClass 'ht-tree-error'
    for file, markerFile of @markers
      for markerReg in markerFile
        for shownMarker in markerReg.markers
          shownMarker.destroy()
    @markers = {}

  # Remove all markers from files in a given package
  removeAllMarkersFromPackage: (pkg) ->
    $('.tree-view .directory').each (i,elem) =>
      if $(elem).children('.header').find('[data-path]').attr('data-path') == pkg
        $(elem).find('.ht-tree-error').removeClass 'ht-tree-error'
    for file, markerFile of @markers
      if file.startsWith(pkg)
        for markerReg in markerFile
            for shownMarker in markerReg.markers
              shownMarker.destroy()
        @markers[file] = []

  # Deregisters and removes all markers that are in a given file.
  removeAllMarkersFromFiles: (files) ->
    $('.tree-view .icon[data-path]').each (i,elem) =>
      if $(elem).attr('data-path') in files
        $(elem).removeClass 'ht-tree-error'
    $('.directory').each (i,elem) =>
      # remove markers on folders without errors in files
      if $(elem).find('.file .ht-tree-error').length == 0
        $(elem).children('.header').find('.icon').removeClass 'ht-tree-error'
    for file in files
      @removeAllMarkersFrom file

  # Removes all error markers from a file
  removeAllMarkersFrom: (file) ->
    for markerReg in @markers[file] ? []
      for shownMarker in markerReg.markers
        shownMarker.destroy()
    @markers[file] = []

  setupListeners: () ->
    if @treeListener
      @treeListener.disconnect()
    @treeListener = new MutationObserver((mutations) => @refreshFileMarkers());
    $ =>
      if $('.tree-view')[0]
        @treeListener.observe($('.tree-view')[0], { childList: true, subtree: true })

  refreshFileMarkers: () ->
    markedFiles = []
    for file, markers of @markers
      if markers.length > 0 then markedFiles.push file
    $('.tree-view .icon[data-path]:not(.ht-tree-error)').each (i,elem) =>
      for file in markedFiles
        if file.startsWith $(elem).attr('data-path')
          $(elem).addClass 'ht-tree-error'
