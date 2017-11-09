markerManager = require './marker-manager'
{$} = require('atom-space-pen-views')

# Shows tooltip boxes displaying the details of the markers placed in the code.
# Only one tooltip can be active at a time.
module.exports = TooltipManager =
  lastTooltip: null # The last tooltip popup
  tooltipTimer: null # The timer related to the last tooltip popup
  lastTooltipElem: null # The elem corresponding to the last tooltip

  activate: () ->

    # Show tooltips on the highlighted elements.
    # Since marker decorations already implemented in Atom are not capable of listening to mouse
    # events, we create a special element above each marker and use it to catch mouseover and display
    # the tooltip.
    markerManager.onMarked ({editor, marker, rng, text}) =>
      editorElement = atom.views.getView(editor)
      # Because view synchronization issues, we must delay the insertion of markers until the file
      # is actually displayed
      $(editorElement).one 'mouseover', () =>
        if !marker.isValid() || marker.isDestroyed()
          return # the marker is invalidated without ever being shown
        screenPos = editor.screenRangeForBufferRange rng
        position = editorElement.pixelRectForScreenRange screenPos
        keeper = $("<div></div>").addClass('ht-comp-problem').css({
                    position: "absolute",
                    top: position.top, left: position.left,
                    width: position.width, height: position.height
                  }).data('msg-text', text)
        # create an overlays div inside the editor page
        if !$(editorElement).find('.scroll-view .overlays').length
          $(editorElement).find('.scroll-view > :first-child').append($('<div class="overlays"></div>'))
        $(editorElement).find('.scroll-view .overlays').append keeper
        # when the marker is changed (moved, resized), also change the overlay
        marker.onDidChange (event) =>
          rng = [ [event.newTailBufferPosition.row, event.newTailBufferPosition.column]
                , [event.newHeadBufferPosition.row, event.newHeadBufferPosition.column] ]
          position = editorElement.pixelRectForScreenRange(editor.screenRangeForBufferRange rng)
          keeper.css({
            top: position.top, left: position.left,
            width: position.width, height: position.height
          })
          keeper.toggle(event.isValid)
        # remove the overlay if the marker is destroyed
        marker.onDidDestroy () => keeper.remove()

    # Showing tooltips when hovering over the markers (both in the gutter and in the text)
    $('atom-workspace').on 'mouseenter', '.editor .ht-comp-problem', (event) =>
      elem = $(event.target)
      if not elem.hasClass('ht-comp-problem')
        return
      @hideShownTooltip()
      tooltip = elem.children('.ht-tooltip')
      if tooltip.length > 0
        # The tooltip already exists
        tooltip.removeClass('invisible')
      else
        # Creating a new tooltip for the marker
        text = $(elem).data('msg-text') || markerManager.getMarkerFromElem(elem).text
        # Tooltips are saved to the DOM
        elem.append $("<div class='ht-tooltip'></div>").text(text)
        tooltip = elem.children('.ht-tooltip')
        if text
          # Calculate a good width for the new tooltip
          tooltip.css('min-width', 200 + Math.min(200, text.length * 2))
      @lastTooltip = tooltip
      @lastTooltipElem = elem

    $('atom-workspace').on 'mouseenter', '.editor .ht-comp-problem .ht-tooltip', (event) =>
      clearTimeout @tooltipTimer

    $('atom-workspace').on 'mouseout', '.editor .ht-comp-problem', (event) =>
      hiding = () => $(@lastTooltip).addClass('invisible')
      @tooltipTimer = setTimeout hiding, 1000

    $('atom-workspace').on 'click', '.editor .lines', (event) =>
      @hideShownTooltip()

  hideShownTooltip: () ->
    if @lastTooltip
      $(@lastTooltip).addClass('invisible')
      @lastTooltip = null
      @lastTooltipElem = null
      clearTimeout @tooltipTimer

  refresh: () ->
    @lastTooltip = null
    @lastTooltipElem = null
    $('.ht-tooltip').remove()


  dispose: () ->
    # Remove attached event listeners
    $('atom-workspace').off 'mouseenter', '.editor .ht-comp-problem'
    $('atom-workspace').off 'mouseenter', '.editor .ht-comp-problem .ht-tooltip'
    $('atom-workspace').off 'mouseout', '.editor .ht-comp-problem'
