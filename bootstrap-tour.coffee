### ============================================================
# bootstrap-tour.js v0.1
# http://pushly.github.com/bootstrap-tour/
# ==============================================================
# Copyright 2012 Push.ly
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
###

(($, window) ->
  document = window.document

  class Tour
    constructor: (options) ->
      @_options = $.extend({
        name: 'tour'
        labels: {
          end: 'End tour'
          next: 'Next &raquo;'
          prev: '&laquo; Prev'
        }
        keyboard: true,
        useLocalStorage: false,
        afterSetState: (key, value) ->
        afterGetState: (key, value) ->
        onStart: (tour) ->
        onEnd: (tour) ->
        onShow: (tour) ->
        onHide: (tour) ->
        onShown: (tour) ->
      }, options)

      @_steps = []
      @setCurrentStep()

      # Reshow popover on window resize using debounced resize
      @_onresize(=> @showStep(@_current) unless @ended)

    setState: (key, value) ->
      if this._options.useLocalStorage
        window.localStorage.setItem("#{@_options.name}_#{key}", value)
      else
        $.cookie("#{@_options.name}_#{key}", value, { expires: 36500, path: '/' })
      @_options.afterSetState(key, value)

    getState: (key) ->
      if this._options.useLocalStorage
        value = window.localStorage.getItem("#{@_options.name}_#{key}")
      else
        value = $.cookie("#{@_options.name}_#{key}")

      value = null if value == undefined || value == "null"

      @_options.afterGetState(key, value)
      return value

    # Add a new step
    addStep: (step) ->
      @_steps.push step

    # Get a step by its indice
    getStep: (i) ->
      $.extend({
        path: ""
        placement: "right"
        title: ""
        content: ""
        next: if i == @_steps.length - 1 then -1 else i + 1
        prev: i - 1
        animation: true
        onShow: @_options.onShow
        onHide: @_options.onHide
        onShown: @_options.onShown
      }, @_steps[i]) if @_steps[i]?

    # Start tour from current step
    start: (force = false) ->
      return if @ended() && !force

      # Go to next step after click on element with class .next
      $(document).off("click.bootstrap-tour",".popover .next").on "click.bootstrap-tour", ".popover .next", (e) =>
        e.preventDefault()
        @next()

      # Go to previous step after click on element with class .prev
      $(document).off("click.bootstrap-tour",".popover .prev").on "click.bootstrap-tour", ".popover .prev", (e) =>
        e.preventDefault()
        @prev()

      # End tour after click on element with class .end
      $(document).off("click.bootstrap-tour",".popover .end").on "click.bootstrap-tour", ".popover .end", (e) =>
        e.preventDefault()
        @end()

      @_setupKeyboardNavigation()

      @_options.onStart(@) if @_options.onStart?

      @showStep(@_current)

    # Hide current step and show next step
    next: ->
      @hideStep(@_current)
      @showNextStep()

    # Hide current step and show prev step
    prev: ->
      @hideStep(@_current)
      @showPrevStep()

    # End tour
    end: ->
      @hideStep(@_current)
      $(document).off "click.bootstrap-tour"
      $(document).off "keyup.bootstrap-tour"
      @setState("end", "yes")

      @_options.onEnd(@) if @_options.onEnd?

    # Verify if tour is enabled
    ended: ->
      !!@getState("end")

    # Restart tour
    restart: ->
      @setState("current_step", null)
      @setState("end", null)
      @setCurrentStep(0)
      @start()

    # Hide the specified step
    hideStep: (i) ->
      step = @getStep(i)
      step.onHide(@) if step.onHide?

      $(step.element).popover("hide")

    # Show the specified step
    showStep: (i) ->
      step = @getStep(i)

      return unless step

      @setCurrentStep(i)

      # Support string or function for path
      path = if typeof step.path == "function" then step.path.call() else step.path

      # Redirect to step path if not already there
      if @_redirect(path, document.location.pathname)
        document.location.href = path
        return

      step.onShow(@) if step.onShow?

      # If step element is hidden, skip step
      unless step.element? && $(step.element).length != 0 && $(step.element).is(":visible")
        @showNextStep()
        return

      # Show popover
      @_showPopover(step, i)

      step.onShown(@) if step.onShown?

    # Setup current step variable
    setCurrentStep: (value) ->
      if value?
        @_current = value
        @setState("current_step", value)
      else
        @_current = @getState("current_step")
        if @_current == null
          @_current = 0
        else
          @_current = parseInt(@_current)

    # Show next step
    showNextStep: ->
      step = @getStep(@_current)
      @showStep(step.next)

    # Show prev step
    showPrevStep: ->
      step = @getStep(@_current)
      @showStep(step.prev)

    # Check if step path equals current document path
    _redirect: (path, currentPath) ->
      path? and path isnt "" and
        path.replace(/\?.*$/, "").replace(/\/?$/, "") isnt currentPath.replace(/\/?$/, "")

    # Show step popover
    _showPopover: (step, i) ->
      content = "#{step.content}<br /><p>"

      options = $.extend {}, @_options

      if step.options
        $.extend options, step.options
      if step.reflex
        $(step.element).css "cursor", "pointer"
        $(step.element).on "click", (e) =>
          $(step.element).css "cursor", "auto"
          @next()

      nav = []

      if step.prev >= 0
        nav.push "<a href='##{step.prev}' class='prev'>#{options.labels.prev}</a>"
      if step.next >= 0
        nav.push "<a href='##{step.next}' class='next'>#{options.labels.next}</a>"
      content += nav.join(" | ")

      content += "<a href='#' class='pull-right end'>#{options.labels.end}</a>"

      $(step.element).popover('destroy').popover({
        placement: step.placement
        trigger: "manual"
        title: step.title
        content: content
        html: true
        animation: step.animation
        container: "body"
      }).popover("show")

      tip = $(step.element).data("popover").tip()
      @_reposition(tip, step)
      @_scrollIntoView(tip)

    # Prevent popups from crossing over the edge of the window
    _reposition: (tip, step) ->
      original_offsetWidth = tip[0].offsetWidth
      original_offsetHeight = tip[0].offsetHeight

      tipOffset = tip.offset()
      original_left = tipOffset.left
      original_top = tipOffset.top
      offsetBottom = $(document).outerHeight() - tipOffset.top - $(tip).outerHeight()
      tipOffset.top = tipOffset.top + offsetBottom if offsetBottom < 0
      offsetRight = $("html").outerWidth() - tipOffset.left - $(tip).outerWidth()
      tipOffset.left = tipOffset.left + offsetRight if offsetRight < 0

      tipOffset.top = 0 if tipOffset.top < 0
      tipOffset.left = 0 if tipOffset.left < 0

      tip.offset(tipOffset)

      # reposition the arrow
      if step.placement == 'bottom' or step.placement == 'top'
        @_replaceArrow(tip, (tipOffset.left-original_left)*2, original_offsetWidth, 'left') if original_left != tipOffset.left
      else
        @_replaceArrow(tip, (tipOffset.top-original_top)*2, original_offsetHeight, 'top') if original_top != tipOffset.top

    # copy pasted from bootstrap-tooltip.js
    # with some alterations
    _replaceArrow: (tip, delta, dimension, position)->
      tip
        .find(".arrow")
        .css(position, if delta then (50 * (1 - delta / dimension) + "%") else '')

    # Scroll to the popup if it is not in the viewport
    _scrollIntoView: (tip) ->
      tipRect = tip.get(0).getBoundingClientRect()
      unless tipRect.top >= 0 && tipRect.bottom < $(window).height() && tipRect.left >= 0 && tipRect.right < $(window).width()
        tip.get(0).scrollIntoView(true)

    # Debounced window resize
    _onresize: (cb, timeout) ->
      $(window).resize ->
        clearTimeout(timeout)
        timeout = setTimeout(cb, 100)

    # Keyboard navigation
    _setupKeyboardNavigation: ->
      if @_options.keyboard
        $(document).on "keyup.bootstrap-tour", (e) =>
          return unless e.which
          switch e.which
            when 39
              e.preventDefault()
              if @_current < @_steps.length - 1
                @next()
            when 37
              e.preventDefault()
              if @_current > 0
                @prev()

  window.Tour = Tour

)(jQuery, window)
