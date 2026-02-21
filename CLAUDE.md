# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Port Watcher — a lightweight macOS menu bar app that lists active TCP listening processes, shows port/PID/command/cwd, and allows killing them. Built for solo developers managing local dev servers.

## Build & Run

```bash
make install   # build Release + copy to /Applications
make run       # install + launch
make uninstall # remove from /Applications
make clean     # delete local build dir
```

Override install location: `make install INSTALL_DIR=~/Applications`

**Alternative (xcodebuild directly):**
```bash
xcodebuild -project PortWatcher.xcodeproj -scheme PortWatcher -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/PortWatcher-*/Build/Products/Debug/PortWatcher.app
```

No signing or sandboxing required. Full Disk Access recommended for accurate cwd resolution.

## Architecture

- **Platform:** macOS 14+, Swift 6, SwiftUI
- **UI pattern:** `MenuBarExtra` with `.window` style (popover from menu bar icon). `LSUIElement = true` in Info.plist hides Dock icon.
- **Source layout:** All source files in `PortWatcher/`
  - `PortWatcherApp.swift` — `@main` App with MenuBarExtra scene
  - `PortProcess.swift` — data model (port, pid, command, cwd)
  - `ProcessScanner.swift` — `@MainActor @Observable` class; shells out to `lsof`/`ps` on a detached task, parses output, manages state
  - `ContentView.swift` — SwiftUI list with kill buttons, refresh, quit, ignore controls
- **Process detection:** `lsof -iTCP -sTCP:LISTEN -n -P` filtered to current user, enriched with `ps -o command=` and `lsof -d cwd` per PID
- **Kill behavior:** SIGTERM via Kill, SIGKILL via Force Kill (both in context menu)
- **Ignore list:** Command names stored in UserDefaults, clearable via footer button
- **Auto-refresh:** 5-second async timer loop in `startAutoRefresh()`
