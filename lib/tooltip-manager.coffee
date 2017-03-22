markerManager = require './marker-manager'
{$} = require('atom-space-pen-views')

# Shows tooltip boxes displaying the details of the markers placed in the code.
# Only one tooltip can be active at a time.
module.exports = TooltipManager =
  lastTooltip: null # The last tooltip popup
  tooltipTimer: null # The timer related to the last tooltip popup
  lastTooltipElem: null # The elem corresponding to the last tooltip

  activate: () ->
    # Showing tooltips when hovering over the markers
    # Note: I wanted to show these on the marked source code fragment but the
    # highlight is below the text, and placing it above cause visual problems.
    # This could be solved by a mouseover on the whole editor and checking if
    # the mouse is actually over a problem, but this seems to overdo the job.
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
        marker = markerManager.getMarkerFromElem elem
        # Tooltips are saved to the DOM
        elem.append("<div class='ht-tooltip'>#{marker.text}</div>")
        tooltip = elem.children('.ht-tooltip')
        if marker.text
          # Calculate a good width for the new tooltip
          tooltip.width(200 + Math.min(200, marker.text.length * 2))
      @lastTooltip = tooltip
      @lastTooltipElem = elem

    $('atom-workspace').on 'mouseenter', '.editor .ht-comp-problem .ht-tooltip', (event) =>
      clearTimeout @tooltipTimer

    $('atom-workspace').on 'mouseout', '.editor .ht-comp-problem', (event) =>
      hiding = () => $(@lastTooltip).addClass('invisible')
      @tooltipTimer = setTimeout hiding, 1000

  hideShownTooltip: () ->
    if @lastTooltip
      $(@lastTooltip).addClass('invisible')
      @lastTooltip = null
      @lastTooltipElem = null
      clearTimeout @tooltipTimer

  dispose: () ->
    # Remove attached event listeners
    $('atom-workspace').off 'mouseenter', '.editor .ht-comp-problem'
    $('atom-workspace').off 'mouseenter', '.editor .ht-comp-problem .ht-tooltip'
    $('atom-workspace').off 'mouseout', '.editor .ht-comp-problem'
