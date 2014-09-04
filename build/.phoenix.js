var APP_FRAMES, BROWSER, EDITOR, FINDER, GRID_HEIGHT, GRID_WIDTH, MARGIN_X, MARGIN_Y, MUSIC, ScreenGrid, TERMINAL, VIDEO, coversCell, debug, focusGrid, hardMash, key_binding, lastFrames, mash, moveAllToDefault, snapAllToGrid, toCell,
  __slice = [].slice;

debug = function(message) {
  return api.alert(message, 10);
};

MARGIN_X = 0;

MARGIN_Y = 0;

GRID_WIDTH = 2;

GRID_HEIGHT = 2;

EDITOR = "PyCharm";

BROWSER = "Google Chrome";

TERMINAL = "Terminal";

FINDER = "Finder";

MUSIC = "Spotify";

VIDEO = "Plex Home Theater";

APP_FRAMES = {
  "HipChat": {
    x: 0,
    y: 0
  },
  "Mailbox (Beta)": {
    x: 0,
    y: 0
  },
  "Calendar": {
    x: 0,
    y: 1
  },
  "Reminders": {
    x: 0,
    y: 1
  },
  "Google Chrome": {
    x: 1,
    y: 0,
    height: 2
  },
  "Sublime Text": {
    x: 2,
    y: 0,
    height: 2
  },
  "PyCharm": {
    x: 2,
    y: 0,
    height: 2
  },
  "RubyMine": {
    x: 2,
    y: 0,
    height: 2
  },
  "Terminal": {
    x: 3,
    y: 0
  },
  "Dash": {
    x: 3,
    y: 1
  },
  "GitHub": {
    x: 3,
    y: 1
  },
  "Harvest": {
    x: 3,
    y: 1
  }
};

ScreenGrid = (function() {
  function ScreenGrid() {
    this.screens = ScreenGrid.screens();
  }

  ScreenGrid.prototype.getScreenFrame = function(gridFrame) {
    var cellHeight, cellWidth, newFrame, screen, screenIndex, screenRect;
    screenIndex = Math.floor(gridFrame.x / GRID_WIDTH);
    if (screenIndex > this.screens.length) {
      screenIndex = 0;
    }
    screen = this.screens[screenIndex] || this.screens[0];
    gridFrame = {
      x: gridFrame.x % GRID_WIDTH,
      y: gridFrame.y,
      width: gridFrame.width || 1,
      height: gridFrame.height || 1
    };
    screenRect = screen.frameWithoutDockOrMenu();
    cellWidth = screenRect.width / GRID_WIDTH;
    cellHeight = screenRect.height / GRID_HEIGHT;
    newFrame = {
      x: (gridFrame.x * cellWidth) + screenRect.x,
      y: (gridFrame.y * cellHeight) + screenRect.y,
      width: gridFrame.width * cellWidth,
      height: gridFrame.height * cellHeight
    };
    newFrame.x += MARGIN_X;
    newFrame.y += MARGIN_Y;
    newFrame.width -= MARGIN_X * 2.0;
    newFrame.height -= MARGIN_Y * 2.0;
    return newFrame;
  };

  ScreenGrid.prototype.closestGridFrame = function(win, rounded) {
    var allowedXDelta, allowedYDelta, cellHeight, cellWidth, gridFrame, screenIndex, screenRect, winFrame;
    if (rounded == null) {
      rounded = true;
    }
    winFrame = win.frame();
    screenRect = win.screen().frameWithoutDockOrMenu();
    cellWidth = screenRect.width / GRID_WIDTH;
    cellHeight = screenRect.height / GRID_HEIGHT;
    if (!rounded) {
      allowedXDelta = 20 / cellWidth;
      allowedYDelta = 20 / cellHeight;
      if (!(this.isWholeNum((winFrame.x - screenRect.x) / cellWidth, allowedXDelta) && this.isWholeNum((winFrame.y - screenRect.y) / cellHeight, allowedYDelta) && this.isWholeNum(winFrame.width / cellWidth, allowedXDelta) && this.isWholeNum(winFrame.height / cellHeight, allowedYDelta))) {
        return;
      }
    }
    gridFrame = {
      x: Math.round((winFrame.x - screenRect.x) / cellWidth),
      y: Math.round((winFrame.y - screenRect.y) / cellHeight),
      width: Math.max(1, Math.round(winFrame.width / cellWidth)),
      height: Math.max(1, Math.round(winFrame.height / cellHeight))
    };
    screenIndex = this.screens.indexOf(win.screen());
    gridFrame.x += screenIndex * GRID_WIDTH;
    return gridFrame;
  };

  ScreenGrid.prototype.isWholeNum = function(number, delta) {
    return Math.abs(Math.round(number) - number) <= delta;
  };

  ScreenGrid.closestGridFrame = function() {
    var args, _ref;
    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return (_ref = new this()).closestGridFrame.apply(_ref, args);
  };

  ScreenGrid.getScreenFrame = function() {
    var args, _ref;
    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return (_ref = new this()).getScreenFrame.apply(_ref, args);
  };

  ScreenGrid.screens = function() {
    var curScreen, firstScreen, screens;
    firstScreen = Window.focusedWindow().screen();
    curScreen = firstScreen.nextScreen();
    screens = [curScreen];
    while (curScreen !== firstScreen) {
      curScreen = curScreen.nextScreen();
      screens.push(curScreen);
    }
    return _.chain(screens).map(function(screen) {
      var x, y, _ref;
      _ref = screen.frameWithoutDockOrMenu(), x = _ref.x, y = _ref.y;
      return {
        x: x,
        y: y,
        screen: screen
      };
    }).sortBy('y').sortBy('x').pluck('screen').value();
  };

  return ScreenGrid;

})();

snapAllToGrid = function() {
  var grid;
  grid = new ScreenGrid();
  return Window.visibleWindows().map(function(win) {
    win.snapToGrid(grid);
  });
};

moveAllToDefault = function() {
  var grid;
  grid = new ScreenGrid();
  return Window.visibleWindows().map(function(win) {
    var frame;
    if (!win.isNormalWindow()) {
      return;
    }
    if (frame = APP_FRAMES[win.app().title()]) {
      win.setFrame(grid.getScreenFrame(frame));
    }
  });
};

Window.prototype.snapToGrid = function(grid) {
  var frame;
  if (grid == null) {
    grid = ScreenGrid;
  }
  if (!this.isNormalWindow()) {
    return;
  }
  frame = grid.closestGridFrame(win);
  return this.setFrame(grid.getScreenFrame(frame));
};

Window.prototype.info = function() {
  var f;
  f = this.frame();
  return "[" + (this.app().pid) + "] " + (this.app().title()) + " : " + (this.title()) + "\n{x:" + f.x + ", y:" + f.y + ", width:" + f.width + ", height:" + f.height + "}\n";
};

lastFrames = {};

Window.prototype.toFullScreen = function() {
  var fullFrame;
  fullFrame = this.screen().frameWithoutDockOrMenu();
  if (!_.isEqual(this.frame(), fullFrame)) {
    this.rememberFrame();
    return this.setFrame(fullFrame);
  } else if (lastFrames[this]) {
    this.setFrame(lastFrames[this]);
    return this.forgetFrame();
  }
};

Window.prototype.rememberFrame = function() {
  return lastFrames[this] = this.frame();
};

Window.prototype.forgetFrame = function() {
  return delete lastFrames[this];
};

toCell = function(x, y) {
  var frame, screenGrid, win;
  win = Window.focusedWindow();
  screenGrid = new ScreenGrid();
  frame = screenGrid.closestGridFrame(win, false);
  if (frame && frame.x === x && frame.y === y) {
    frame.height = frame.height !== 1 ? 1 : GRID_HEIGHT;
    if (frame.height === GRID_HEIGHT) {
      frame.y = 0;
    }
    return win.setFrame(screenGrid.getScreenFrame(frame));
  } else {
    return win.setFrame(screenGrid.getScreenFrame({
      x: x,
      y: y
    }));
  }
};

focusGrid = function(x, y) {
  var isCellFocused, screenGrid, windows;
  screenGrid = new ScreenGrid();
  windows = Window.visibleWindowsMostRecentFirst();
  windows = windows.filter(function(win) {
    var frame;
    frame = screenGrid.closestGridFrame(win, false);
    return frame && coversCell(frame, x, y);
  });
  isCellFocused = _.map(windows, function(w) {
    return w.info();
  }).indexOf(Window.focusedWindow().info()) > -1;
  if (isCellFocused) {
    return windows[windows.length - 1].focusWindow();
  } else if (windows.length) {
    return windows[0].focusWindow();
  }
};

coversCell = function(frame, x, y) {
  var frameBottom, frameRight;
  frameRight = frame.x + frame.width;
  frameBottom = frame.y + frame.height;
  return (frame.x <= x && x < frameRight) && (frame.y <= y && y < frameBottom);
};

App.prototype.firstWindow = function() {
  return this.visibleWindows()[0];
};

App.byTitle = function(title) {
  var app, apps, i;
  apps = this.runningApps();
  i = 0;
  while (i < apps.length) {
    app = apps[i];
    if (app.title() === title) {
      app.show();
      return app;
    }
    i++;
  }
};

App.allWithTitle = function(title) {
  return _(this.runningApps()).filter(function(app) {
    if (app.title() === title) {
      return true;
    }
  });
};

App.focusOrStart = function(title) {
  var activeWindows, apps, windows;
  apps = App.allWithTitle(title);
  if (_.isEmpty(apps)) {
    api.alert("Attempting to start " + title);
    api.launch(title);
    return;
  }
  windows = _.chain(apps).map(function(x) {
    return x.allWindows();
  }).flatten().value();
  activeWindows = _(windows).reject(function(win) {
    return win.isWindowMinimized();
  });
  if (_.isEmpty(activeWindows)) {
    api.launch(title);
  }
  activeWindows.forEach(function(win) {
    win.focusWindow();
  });
};

key_binding = function(key, modifier, fn) {
  return api.bind(key, modifier, fn);
};

mash = 'cmd+alt+ctrl'.split('+');

hardMash = 'shift+cmd+alt+ctrl'.split('+');

key_binding('space', mash, function() {
  return Window.focusedWindow().toFullScreen();
});

key_binding('0', mash, function() {
  return App.focusOrStart(EDITOR);
});

key_binding('9', mash, function() {
  return App.focusOrStart(TERMINAL);
});

key_binding('8', mash, function() {
  return App.focusOrStart(BROWSER);
});

key_binding('7', mash, function() {
  return App.focusOrStart(FINDER);
});

key_binding('V', mash, function() {
  return App.focusOrStart(VIDEO);
});

key_binding('B', mash, function() {
  return App.focusOrStart(MUSIC);
});

key_binding("'", mash, function() {
  return snapAllToGrid();
});

key_binding("'", hardMash, function() {
  return moveAllToDefault();
});

key_binding('U', hardMash, function() {
  return toCell(0, 0);
});

key_binding('J', hardMash, function() {
  return toCell(0, 1);
});

key_binding('I', hardMash, function() {
  return toCell(1, 0);
});

key_binding('K', hardMash, function() {
  return toCell(1, 1);
});

key_binding('O', hardMash, function() {
  return toCell(2, 0);
});

key_binding('L', hardMash, function() {
  return toCell(2, 1);
});

key_binding('P', hardMash, function() {
  return toCell(3, 0);
});

key_binding(';', hardMash, function() {
  return toCell(3, 1);
});

key_binding('Æ', hardMash, function() {
  return toCell(3, 1);
});

key_binding('U', mash, function() {
  return focusGrid(0, 0);
});

key_binding('J', mash, function() {
  return focusGrid(0, 1);
});

key_binding('I', mash, function() {
  return focusGrid(1, 0);
});

key_binding('K', mash, function() {
  return focusGrid(1, 1);
});

key_binding('O', mash, function() {
  return focusGrid(2, 0);
});

key_binding('L', mash, function() {
  return focusGrid(2, 1);
});

key_binding('P', mash, function() {
  return focusGrid(3, 0);
});

key_binding(';', mash, function() {
  return focusGrid(3, 1);
});

key_binding('Æ', mash, function() {
  return focusGrid(3, 1);
});
