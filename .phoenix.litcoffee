# Phoenix.app config

## Prologue

This is a nice, fairly comprehensive, relatively self-documenting,
configuration for [Phoenix.app](https://github.com/sdegutis/Phoenix),
a lightweight scriptable OS X window manager.

## [Jump straight to the bindings](#bindings)

## Usage

Install Phoenix.app, and convert this file (`.phoenix.litcoffee`) to
plain JS, for use with Phoenix.app using:

```shell
coffee --bare --literate --compile .phoenix.litcoffee
```

(Or use the Makefile included in this gist)

### Install CoffeeScript

If you don't have CoffeeScript installed, you'll need to [install
node/npm](https://github.com/joyent/node/wiki/installation) (or use
`brew install node --with-npm`) first, and then:

```shell
npm install -g coffee-script
```

## Debugging helpers

We'll use a 20 second alert to show debug messages, +1 for a Phoenix REPL!

    debug = (message)->
      api.alert message, 10

## Basic Settings

    MARGIN_X     = 0
    MARGIN_Y     = 0
    GRID_WIDTH   = 2
    GRID_HEIGHT  = 2

## Application config

    EDITOR       = "PyCharm"
    BROWSER      = "Google Chrome"
    TERMINAL     = "Terminal"
    FINDER       = "Finder"
    MUSIC        = "Spotify"
    VIDEO        = "Plex Home Theater"

## Default app frames

    appFrames = 
      "HipChat": x: 0, y: 0
      "Mailbox (Beta)": x: 0, y: 0

      "Calendar": x: 0, y: 1
      "Reminders": x: 0, y: 1

      "Google Chrome": x: 1, y: 0, height: 2

      "Sublime Text": x: 2, y: 0, height: 2
      "PyCharm": x: 2, y: 0, height: 2
      "RubyMine": x: 2, y: 0, height: 2

      "GitHub": x: 2, y: 1
      "Harvest": x: 2, y: 1

      "Terminal": x: 3, y: 0

      "Dash": x: 3, y: 1

## Layout config

A few helpful app layouts. **note:** The last app in a layout array
will get focus.

    layouts =
      "Editor and Browser":
        0: app: BROWSER,  whereTo: "toRightHalf"
        1: app: EDITOR,   whereTo: "toLeftHalf"

      "Editor and Terminal":
        0: app: TERMINAL, whereTo: "toRightHalf"
        1: app: EDITOR,   whereTo: "toLeftHalf"

      "Terminal and Browser":
        0: app: TERMINAL, whereTo: "toLeftHalf"
        1: app: BROWSER,  whereTo: "toRightHalf"

      "Finder and Terminal":
        0: app: TERMINAL, whereTo: "toRightHalf"
        1: app: FINDER,   whereTo: "toLeftHalf"

      "Finder and Browser": 
        0: app: BROWSER,  whereTo: "toRightHalf"
        1: app: FINDER,   whereTo: "toLeftHalf"

## Methods

### Screen Meta

    class ScreenGrid
      constructor: ->
        @screens = ScreenGrid.screens()

      getScreenFrame: (gridFrame) ->
        screenIndex = Math.floor(gridFrame.x / GRID_WIDTH)
        screenIndex = 0 if (screenIndex > @screens.length)
        screen = @screens[screenIndex] || @screens[0]

        # Change to intra-screen grid.
        gridFrame =
          x: gridFrame.x % GRID_WIDTH
          y: gridFrame.y
          width: gridFrame.width || 1
          height: gridFrame.height || 1

        screenRect = screen.frameWithoutDockOrMenu()
        halfScreenWidth = screenRect.width / GRID_WIDTH
        halfScreenHeight = screenRect.height / GRID_HEIGHT
        newFrame =
          x: (gridFrame.x * halfScreenWidth) + screenRect.x
          y: (gridFrame.y * halfScreenHeight) + screenRect.y
          width: gridFrame.width * halfScreenWidth
          height: gridFrame.height * halfScreenHeight
        newFrame.x += MARGIN_X
        newFrame.y += MARGIN_Y
        newFrame.width -= (MARGIN_X * 2.0)
        newFrame.height -= (MARGIN_Y * 2.0)
        return newFrame

      closestGridFrame: (win, rounded = true) ->
        winFrame = win.frame()
        screenRect = win.screen().frameWithoutDockOrMenu()
        halfScreenWidth = screenRect.width / GRID_WIDTH
        halfScreenHeight = screenRect.height / GRID_HEIGHT

Normally the function always return a grid frame. By changing `rounded` to
false, it will return null unless the window frame is positioned directly on the grid.

        unless rounded
          allowedXDelta = 20 / halfScreenWidth
          allowedYDelta = 20 / halfScreenWidth
          unless @isWholeNum((winFrame.x - screenRect.x) / halfScreenWidth, allowedXDelta) and
              @isWholeNum((winFrame.y - screenRect.y) / halfScreenHeight, allowedYDelta) and
              @isWholeNum(winFrame.width / halfScreenWidth, allowedXDelta) and
              @isWholeNum(winFrame.height / halfScreenHeight, allowedYDelta)
            return

        gridFrame =
          x: Math.round((winFrame.x - screenRect.x) / halfScreenWidth)
          y: Math.round((winFrame.y - screenRect.y) / halfScreenHeight)
          width: Math.max(1, Math.round(winFrame.width / halfScreenWidth))
          height: Math.max(1, Math.round(winFrame.height / halfScreenHeight))

        screenIndex = @screens.indexOf(win.screen())
        gridFrame.x += screenIndex * GRID_WIDTH
        return gridFrame

      isWholeNum: (number, delta) ->
        Math.abs(Math.round(number) - number) <= delta

      @closestGridFrame: (args...) ->
        new @().closestGridFrame(args...)

      @getScreenFrame: (args...) ->
        new @().getScreenFrame(args...)

      @screens: (win) ->
        # Enumerate all available screens
        firstScreen = Window.focusedWindow().screen()
        curScreen = firstScreen.nextScreen()
        screens = [curScreen]
        while curScreen != firstScreen
          curScreen = curScreen.nextScreen()
          screens.push(curScreen)

        # Sort screens by X position, Y position second.
        _.chain(screens)
          .map (screen) ->
            {x, y} = screen.frameWithoutDockOrMenu()
            {x, y, screen}
          .sortBy 'y'
          .sortBy 'x'
          .pluck 'screen'
          .value()


### Window Grid

Snap all windows to grid layout

    snapAllToGrid = ->
      grid = new ScreenGrid()
      Window.visibleWindows().map (win) ->
        win.snapToGrid(grid)
        return

Move all windows to their default application positions.

    moveAllToDefault = ->
      grid = new ScreenGrid()
      Window.visibleWindows().map (win) ->
        return unless win.isNormalWindow()

        if frame = appFrames[win.app().title()]
          win.setFrame(grid.getScreenFrame(frame))
        return

Snap the current window to the grid

    Window::snapToGrid = (grid = ScreenGrid) ->
      return unless @isNormalWindow()

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
      fullFrame = @calculateGrid(0, 0, 1, 1)
      unless _.isEqual(@frame(), fullFrame)
        @rememberFrame()
        @toCell 0, 0, 1, 1
      else if lastFrames[this]
        @setFrame lastFrames[this]
        @forgetFrame()

Remember and forget frames

    Window::rememberFrame = -> lastFrames[this] = @frame()
    Window::forgetFrame = -> delete lastFrames[this]

Move the current window to a grid cell

    toCell = (x, y) ->
      win = Window.focusedWindow()
      screenGrid = new ScreenGrid()
      frame = screenGrid.closestGridFrame(win, false)
      if frame and frame.x == x and frame.y == y
        frame.height = if frame.height != 1 then 1 else GRID_HEIGHT
        frame.y = 0 if frame.height == GRID_HEIGHT
        win.setFrame(screenGrid.getScreenFrame(frame))
      else
        win.setFrame(screenGrid.getScreenFrame(x: x, y: y))

    focusGrid = (x, y) ->
      screenGrid = new ScreenGrid()
      windows = Window.visibleWindowsMostRecentFirst()
      windows = windows.filter (win) ->
        frame = screenGrid.closestGridFrame(win, false)
        frame && coversCell(frame, x, y)

      isCellFocused = _.map(windows, (w) -> w.info()).indexOf(Window.focusedWindow().info()) > -1

      if isCellFocused
        windows[windows.length - 1].focusWindow()
      else if windows.length
        windows[0].focusWindow()

    coversCell = (frame, x, y) ->
      frameRight = frame.x + frame.width
      frameBottom = frame.y + frame.height
      frame.x <= x < frameRight and frame.y <= y < frameBottom

### Applications

Select the first window for an app

    App::firstWindow = -> @visibleWindows()[0]

Find an app by it's `title`

    App.byTitle = (title) ->
      apps = @runningApps()
      i = 0
      while i < apps.length
        app = apps[i]
        if app.title() is title
          app.show()
          return app
        i++
      return

Find all apps with `title`

    App.allWithTitle = (title) ->
      _(@runningApps()).filter (app) ->
        true  if app.title() is title

Focus or start an app with `title`

    App.focusOrStart = (title) ->
      apps = App.allWithTitle(title)
      if _.isEmpty(apps)
        api.alert "Attempting to start #{title}"
        api.launch title
        return

      windows = _.chain(apps)
      .map (x) ->
        x.allWindows()
      .flatten()
      .value()

      activeWindows = _(windows)
      .reject (win) ->
        win.isWindowMinimized()

      if _.isEmpty(activeWindows)
        api.launch title

      activeWindows.forEach (win) ->
        win.focusWindow()
        return
      return

### Manage layouts

Switch to a predefined layout [as above](#layout-config)

    switchLayout = (name)->
      _.each layouts[name], (config)->
        App.focusOrStart config.app
        app = App.byTitle config.app
        app.firstWindow()[config.whereTo]()

### Binding alias

Alias `api.bind` as `key_binding`, to make the binding table extra
readable.

    key_binding = (key, modifier, fn)->
      api.bind key, modifier, fn

## Bindings

### Keyboard Guide

Mash is **Cmd** + **Alt/Opt** + **Ctrl** pressed together.

    mash = 'cmd+alt+ctrl'.split '+'
    hardMash = 'shift+cmd+alt+ctrl'.split '+'

Maximize the current window

    key_binding 'space',     mash, -> Window.focusedWindow().toFullScreen()

Switch to or lauch apps, as defined in the [Application config](#application-config)

    key_binding '0',     mash, -> App.focusOrStart EDITOR
    key_binding '9',     mash, -> App.focusOrStart TERMINAL
    key_binding '8',     mash, -> App.focusOrStart BROWSER
    key_binding '7',     mash, -> App.focusOrStart FINDER

    # Entertainment apps...

    key_binding 'V',     mash, -> App.focusOrStart VIDEO
    key_binding 'B',     mash, -> App.focusOrStart MUSIC

Switch layouts using the predefined [Layout config](#layout-config)

    key_binding '5',     mash, -> switchLayout 'Editor and Browser'
    key_binding '4',     mash, -> switchLayout 'Editor and Terminal'
    key_binding '3',     mash, -> switchLayout 'Terminal and Browser'
    key_binding '2',     mash, -> switchLayout 'Finder and Terminal'
    key_binding '1',     mash, -> switchLayout 'Finder and Browser'

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

That's all folks.
