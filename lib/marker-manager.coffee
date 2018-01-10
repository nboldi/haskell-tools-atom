{CompositeDisposable, Emitter} = require 'atom'
path = require 'path'
{$} = require('atom-space-pen-views')

# Controls how error markers are registered and displayed when there are compilation
# problems in the source files
module.exports = MarkerManager =
  editors: {} # We store the editors associated with the given files. We use
              # the editor object for putting up markers.
  markers: {} # We store the created markers for each file. Inside the file we
              # identify markers using their index in the list of all markers.
  treeListener: null

  subscriptions: new CompositeDisposable
  emitter: new Emitter

  activate: () ->
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
    for marker in errorMarkers
      if marker.location
        file = marker.location.file.replace /\\|\//g, path.sep
        if @markers[file]
          @removeAllMarkersFromFiles [file]
    for marker in errorMarkers
      @putMarker marker
    @refreshFileMarkers()

  # Registers the given error marker, shows if possible
  putMarker: ({location, message, severity}) ->
    if !location
      atom.notifications.addError("error: #{text}", {dismissable : true})
      return
    file = location.file.replace /\\|\//g, path.sep
    editorsFor = @editors[file]
    $('.tree-view .icon[data-path]').each (i,elem) =>
      if file.startsWith($(elem).attr('data-path') + path.sep) || file == $(elem).attr('data-path')
        $(elem).addClass('ht-tree-error ht-' + severity)
    if not @markers[file]
      @markers[file] = []
    if editorsFor
      markers = []
      for editor in editorsFor
        markers.push @putMarkerOn(editor, location, severity, message)
      @markers[file].push { location: location, severity: severity, text: message, markers: markers }
    else
      # editor is not open
      @markers[file].push { location: location, severity: severity, text: message, markers: [] }

  # Show registered error markers on the given editor.
  putMarkersOn: (editor) ->
    allMarkers = @markers[editor.buffer.file.path] ? []
    for marker in allMarkers
      marker.markers.push @putMarkerOn(editor, marker.location, marker.severity, marker.text)

  # Shows the given error marker on a given editor
  putMarkerOn: (editor, location, severity, message) ->
    {startRow,startCol,endRow,endCol} = location
    rng = [[startRow - 1, startCol - 1], [endRow - 1, endCol - 1]]
    marker = editor.markBufferRange rng
    @emitter.emit 'marked', {editor: editor, marker: marker, rng: rng, text: message}
    editor.decorateMarker(marker, type: 'highlight', class: 'ht-comp-problem ht-' + severity)
    gutter = editor.gutterWithName 'ht-problems'
    gutter.show()
    gutter.decorateMarker(marker, type: 'gutter', class: 'ht-comp-problem ht-' + severity)
    marker

  onMarked: (callback) ->
    @emitter.on 'marked', callback

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

  # Observe the tree view as it changes. We need to put the markers on them.
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
      err = markers.some (m) -> m.severity == "Error"
      warn = markers.some (m) -> m.severity == "Warning"
      if markers.length > 0 
        markedFiles.push [file, if err then "Error" else if warn then "Warning" else "Info"]
    $('.tree-view .icon[data-path]').each (i,elem) =>
      for [file, severity] in markedFiles
        if file.startsWith($(elem).attr('data-path') + path.sep) || file == $(elem).attr('data-path')
          $(elem).removeClass('ht-Error ht-Warning ht-Info')
          $(elem).addClass ('ht-tree-error ht-' + severity)
