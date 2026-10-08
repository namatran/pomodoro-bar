# Pomodoro

A small Pomodoro timer that lives in the macOS menu bar. Built with SwiftUI `MenuBarExtra` as a Swift Package, so it builds with the Command Line Tools alone (no Xcode).

## Features
- Countdown in the menu bar: 🍅 focus, ☕️ short break, 🌴 long break
- Start, pause, reset and skip
- Work / short break / long break cycle, with a long break after every 4th focus session
- Adjustable durations (defaults 25 / 5 / 15 minutes)
- Alarm when a session ends: repeating beeps until you press **Stop alarm** (or Return), start the next session, or 60 seconds pass
- Notification banner when a session ends (bundled app only)
- Count of focus sessions completed today

## Requirements
- macOS 14 or later
- Swift 5.9+ (Xcode or the Command Line Tools: `xcode-select --install`)

## Run
For development, run the bare binary:

```bash
swift run
```

To build the menu-bar-only app (no Dock icon) with notifications:

```bash
./build_app.sh
open Pomodoro.app
```

To start it at login, move `Pomodoro.app` to `/Applications` and add it under System Settings → General → Login Items.

## Notes
- Notification banners need the app bundle. `swift run` still plays the alarm but skips the banner.
- `swift run` and `Pomodoro.app` keep separate settings and daily counts, because macOS stores them per bundle identifier.
- The app is ad-hoc signed, not notarized. It's meant for the Mac that built it; a copy downloaded on another Mac will be blocked by Gatekeeper.

## Layout
```
Sources/Pomodoro/
  PomodoroApp.swift    menu bar entry point
  ContentView.swift    the dropdown panel
  PomodoroTimer.swift  countdown, phase cycle, alarm state
  Phase.swift          phases and duration settings
  Alarm.swift          synthesized beeping alarm
  Notifier.swift       notification banners
  PomodoroLog.swift    completed sessions per day
build_app.sh           wraps the release build in Pomodoro.app
```
