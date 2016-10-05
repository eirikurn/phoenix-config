# Phoenix.app config

## Prologue

This is a nice, fairly comprehensive, relatively self-documenting,
configuration for [Phoenix.app](https://github.com/sdegutis/Phoenix),
a lightweight scriptable OS X window manager.

## [Jump straight to the bindings](#bindings)

## Usage

Install Phoenix.app, then copy the `build/.phoenix.js` file into your
home folder for use with Phoenix.app.

There is also a gulp script which can build and install the config as
well as watch for changes during development.

```shell
# Install dependencies
npm install

# Build and install config to home folder.
node_modules/.bin/gulp

# Or, watch files and rebuild during development.
# node_modules/.bin/gulp watch
```

## Debugging helpers

We'll use the console to show debug messages.

    debug = (message)->
      Phoenix.log message

## Basic Settings

Margin X and Y are to apply whitespace between window cells.

    MARGIN_X     = 0
    MARGIN_Y     = 0

The grid width and height split each screen into specified rows and columns.

    GRID_WIDTH   = 2
    GRID_HEIGHT  = 2

## Application config

These applications will be launched when certain key bindings are pressed.

    EDITOR       = "PyCharm"
    BROWSER      = "Google Chrome"
    TERMINAL     = "Terminal"
    FINDER       = "Finder"
    MUSIC        = "Spotify"
    VIDEO        = "Plex Home Theater"

## Default app layout

Here we can provide default grid positions for specific apps.

    APP_FRAMES =

Chat:

      "Slack": x: 0, y: 0
      "Messages": x: 0, y: 0

Organisation:

      "Calendar": x: 0, y: 1
      "Reminders": x: 0, y: 1
      "Wunderlist": x: 0, y: 1
      "Notes": x: 0, y: 1
      "Spotify": x: 0, y: 1

Browsing:

      "Google Chrome": x: 1, y: 0, height: 2

Programming:

      "Sublime Text": x: 2, y: 0, height: 2
      "Atom": x: 2, y: 0, height: 2
      "PyCharm": x: 2, y: 0, height: 2
      "RubyMine": x: 2, y: 0, height: 2
      "IntelliJ IDEA": x: 2, y: 0, height: 2

Terminal:

      "Terminal": x: 3, y: 0
      "iTerm2": x: 3, y: 0

Dev support:

      "Dash": x: 3, y: 1
      "GitHub": x: 3, y: 1
      "GitUp": x: 3, y: 1
      "Harvest": x: 3, y: 1

## Methods

### Multi-Screen Grid Control

Phoenix unfortunately doesn't make it easy to query all screens or
overlaying a grid across all screens, so we must be tricky.

We're going to create a class which can pre-calculate the screen grid
for one or more grid operations. The constructor loads a instance array
with all Screen instances, sorted by their layout: left-to-right,
top-to-bottom.

    class ScreenGrid
      constructor: ->
        @screens = ScreenGrid.screens()

With that set, the instance provides two primary methods:

* `getScreenFrame` converts a grid frame (where x, y, width and height
  are cell indices) into absolute screen rectangle.

      getScreenFrame: (gridFrame) ->

  First we'll find out which screen the frame is contained in and map the
  frame to the local grid on that screen.

  Let's say we have 3 screens, each having a 2x2 grid as specified with
  GRID_WIDTH and GRID_HEIGHT, then (5,0) gets mapped to cell (1,0) on
  screen 3. If you specify a cell outside available screens, f.ex. (7,1),
  it will always match the left-most screen.

        screenIndex = Math.floor(gridFrame.x / GRID_WIDTH)
        screenIndex = 0 if (screenIndex > @screens.length)
        screen = @screens[screenIndex] || @screens[0]

        # Change to intra-screen grid.
        gridFrame =
          x: gridFrame.x % GRID_WIDTH
          y: gridFrame.y
          width: gridFrame.width || 1
          height: gridFrame.height || 1

  With that figured out, we can create absolute positions based on the
  local screen frame and grid.

        screenRect = screen.flippedVisibleFrame()
        cellWidth = screenRect.width / GRID_WIDTH
        cellHeight = screenRect.height / GRID_HEIGHT

        newFrame =
          x: (gridFrame.x * cellWidth) + screenRect.x
          y: (gridFrame.y * cellHeight) + screenRect.y
          width: gridFrame.width * cellWidth
          height: gridFrame.height * cellHeight

  Finally apply whitespace between cells before returning the frame.

        newFrame.x += MARGIN_X
        newFrame.y += MARGIN_Y
        newFrame.width -= (MARGIN_X * 2.0)
        newFrame.height -= (MARGIN_Y * 2.0)
        return newFrame

* `closestGridFrame` does the opposite, provided a window frame,
  it figures out the closest matching grid frame with varying precision.
  If `rounded` is true (default), the method will always return a frame,
  otherwise the window needs to be very close to grid borders.

      closestGridFrame: (win, rounded = true) ->
        winFrame = win.frame()
        screenRect = win.screen().flippedVisibleFrame()
        cellWidth = screenRect.width / GRID_WIDTH
        cellHeight = screenRect.height / GRID_HEIGHT

  If we're being precise, we perform a validation on the window frame, making
  sure it's not more than 20 pixels away from a grid border in any direction.

        unless rounded
          allowedXDelta = 20 / cellWidth
          allowedYDelta = 20 / cellHeight
          unless @isWholeNum((winFrame.x - screenRect.x) / cellWidth, allowedXDelta) and
              @isWholeNum((winFrame.y - screenRect.y) / cellHeight, allowedYDelta) and
              @isWholeNum(winFrame.width / cellWidth, allowedXDelta) and
              @isWholeNum(winFrame.height / cellHeight, allowedYDelta)
            return

  Then it's just a matter of rounding the window frame to the closest grid borders.
  All of this is done in the local screen grid.

        gridFrame =
          x: Math.round((winFrame.x - screenRect.x) / cellWidth)
          y: Math.round((winFrame.y - screenRect.y) / cellHeight)
          width: Math.max(1, Math.round(winFrame.width / cellWidth))
          height: Math.max(1, Math.round(winFrame.height / cellHeight))

  Before we return, we transform the local grid frame into a global grid frame based
  on where the screen is.

        screenIndex = @screens.indexOf(win.screen())
        gridFrame.x += screenIndex * GRID_WIDTH
        return gridFrame

Quick helper checks if a floating point `number` is within `delta` from being
an integer.

      isWholeNum: (number, delta) ->
        Math.abs(Math.round(number) - number) <= delta

Let's provide static shortcuts for the instance methods for convenience.

      @closestGridFrame: (args...) ->
        new @().closestGridFrame(args...)

      @getScreenFrame: (args...) ->
        new @().getScreenFrame(args...)

Now here is a tricky bastard. To enumerate all the screens in Phoenix we need
a window reference. Here we are using the currently focused window, which has
been fine in our use cases.

      @screens: ->

We do some underscore woodoo to sort them by their frame, first by X position,
then by Y position.

        # Enumerate all available screens
        _.chain(Screen.all())
          .map (screen) ->
            {x, y} = screen.flippedVisibleFrame()
            {x, y, screen}
          .sortBy 'y'
          .sortBy 'x'
          .pluck 'screen'
          .value()

That's it. Remember the implicit return in Coffeescript? Sweet!

### Window Grid Utilities

Snap all windows to grid layout

    snapAllToGrid = ->
      grid = new ScreenGrid()
      Window.all(visible: true).map (win) ->
        win.snapToGrid(grid)
        return

Moves all windows to their default application positions.

    moveAllToDefault = ->
      grid = new ScreenGrid()
      Window.all(visible: true).map (win) ->
        return unless win.isNormal()
        Phoenix.log("#{win.app().name()}")

        if frame = APP_FRAMES[win.app().name()]
          win.setFrame(grid.getScreenFrame(frame))
        return

Snap the current window to the grid

    Window::snapToGrid = (grid = ScreenGrid) ->
      return unless @isNormal()

      frame = grid.closestGridFrame(win)
      @setFrame grid.getScreenFrame(frame)

### Window information

    Window::info = ->
      f = @frame()
      "[#{@app().pid}] #{@app().title()} : #{@title()}\n{x:#{f.x}, y:#{f.y}, width:#{f.width}, height:#{f.height}}\n"

### Window moving and sizing

Temporary storage for frames

    lastFrames = {}

Set a window to full screen

    Window::toFullScreen = ->
      fullFrame = @screen().flippedVisibleFrame()
      unless _.isEqual(@frame(), fullFrame)
        @rememberFrame()
        @setFrame fullFrame
      else if lastFrames[this]
        @setFrame lastFrames[this]
        @forgetFrame()

Remember and forget frames

    Window::rememberFrame = -> lastFrames[this] = @frame()
    Window::forgetFrame = -> delete lastFrames[this]

Move the focused window to a specific grid cell. If it already fits
that cell, then we'll make it cover the screen vertically.

    toCell = (x, y) ->
      win = Window.focused()
      screenGrid = new ScreenGrid()

Let's check if the window already fits the grid and specified cell,
then just tweak the height.

      frame = screenGrid.closestGridFrame(win, false)
      if frame and frame.x == x and frame.y == y
        frame.height = if frame.height != 1 then 1 else GRID_HEIGHT
        frame.y = 0 if frame.height == GRID_HEIGHT
        win.setFrame(screenGrid.getScreenFrame(frame))

Otherwise move it into position.

      else
        win.setFrame(screenGrid.getScreenFrame(x: x, y: y))

### Focus windows

Method to cycle focus by grid cell.

    focusGrid = (x, y) ->
      screenGrid = new ScreenGrid()

Find all windows that cover the specified cell pretty accurately, sorted
so the most recent window is first.

      windows = Window.recent()
      windows = windows.filter (win) ->
        frame = screenGrid.closestGridFrame(win, false)
        frame && coversCell(frame, x, y)

If any window in the cell doesn't have focus, we'll select the top-most window,
otherwise we'll select the bottom-most window.

By selecting the window on the bottom, we make sure that by repeatedly calling
this method, all windows in the cell will cycle focus.

      focusedWindow = Window.focused()
      isCellFocused = _.find(windows, (w) -> w.equalTo(focusedWindow))

      if isCellFocused
        windows[windows.length - 1].focus()
      else if windows.length
        windows[0].focus()

Utility which returns true if `x` and `y` are covered by the `frame`.

    coversCell = (frame, x, y) ->
      frameRight = frame.x + frame.width
      frameBottom = frame.y + frame.height
      frame.x <= x < frameRight and frame.y <= y < frameBottom

### Applications

Select the first window for an app

    App::firstWindow = -> @windows(visible: true)[0]

Focus or start an app with `title`

    App.focusOrStart = (title) ->
      app = App.get(title)
      if !app
        Phoenix.log "Attempting to start #{title}"
        App.launch title
        return

      windows = app.windows()

      activeWindows = _(windows)
      .reject (win) ->
        win.isMinimized()

      if _.isEmpty(activeWindows)
        App.launch title

      activeWindows.forEach (win) ->
        win.focus()
        return
      return

### Binding alias

Alias `Key.on` as `key_binding`, to make the binding table extra
readable.

    key_binding = (key, modifier, fn)->
      Key.on key, modifier, fn

## Bindings

### Keyboard Guide

Mash is **Cmd** + **Alt/Opt** + **Ctrl** pressed together.

    mash = 'cmd+alt+ctrl'.split '+'
    hardMash = 'shift+cmd+alt+ctrl'.split '+'

Maximize the current window

    key_binding 'space',     mash, -> Window.focused().toFullScreen()

Switch to or lauch apps, as defined in the [Application config](#application-config)

    key_binding '0',     mash, -> App.focusOrStart EDITOR
    key_binding '9',     mash, -> App.focusOrStart TERMINAL
    key_binding '8',     mash, -> App.focusOrStart BROWSER
    key_binding '7',     mash, -> App.focusOrStart FINDER

    # Entertainment apps...

    key_binding 'V',     mash, -> App.focusOrStart VIDEO
    key_binding 'B',     mash, -> App.focusOrStart MUSIC

Snap current window or all windows to the grid

    key_binding "'",     mash, -> snapAllToGrid()
    key_binding "'",     hardMash, -> moveAllToDefault()

Move the current window around the grid

    key_binding 'U',     hardMash, -> toCell(0, 0)
    key_binding 'J',     hardMash, -> toCell(0, 1)
    key_binding 'I',     hardMash, -> toCell(1, 0)
    key_binding 'K',     hardMash, -> toCell(1, 1)
    key_binding 'O',     hardMash, -> toCell(2, 0)
    key_binding 'L',     hardMash, -> toCell(2, 1)
    key_binding 'P',     hardMash, -> toCell(3, 0)
    key_binding ';',     hardMash, -> toCell(3, 1)
    key_binding 'Æ',     hardMash, -> toCell(3, 1)

Focuses the top-most window in a grid cell. If cell already has
focus, cycle focus between windows in same cell.

    key_binding 'U',     mash, -> focusGrid(0, 0)
    key_binding 'J',     mash, -> focusGrid(0, 1)
    key_binding 'I',     mash, -> focusGrid(1, 0)
    key_binding 'K',     mash, -> focusGrid(1, 1)
    key_binding 'O',     mash, -> focusGrid(2, 0)
    key_binding 'L',     mash, -> focusGrid(2, 1)
    key_binding 'P',     mash, -> focusGrid(3, 0)
    key_binding ';',     mash, -> focusGrid(3, 1)
    key_binding 'Æ',     mash, -> focusGrid(3, 1)

That's all folks.
