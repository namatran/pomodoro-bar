# Pomodoro

A focus timer with a desktop pet, for macOS. A small tomato floats on screen and owns the timer, with a slim menu bar item alongside. Built with SwiftUI and AppKit as a Swift Package, so it builds with the Command Line Tools alone (no Xcode).

## Features
- **Pet:** a floating, draggable tomato that bobs gently, shows a face for each state (idle, focus, break, celebrate), and stays on every Space, including over full-screen apps. It remembers where you put it.
- **Popout:** click the pet for a frosted panel with three tabs:
  - **Timer:** Focus | Break modes, Start/Pause and Reset, like Google's timer. Click the clock to type a time; click a running clock to pause it first.
  - **Stopwatch:** counts hundredths, like Google's stopwatch.
  - **Today:** today's sessions and focus total. Click a row and press ⌫ to delete it.
- **Recording:** Reset saves any run of 60 seconds or more, focus or break, finished or not. Quit saves an unsaved run too. Sessions are kept in `~/Library/Application Support/Pomodoro/sessions.json`.
- **Upload:** with a site URL and token set in the dropdown, every saved session is sent to the [pomodoro-web](../pomodoro-web) site, and a row deleted in Today is deleted there too. Anything that fails waits and goes after the next save or at the next launch.
- **Alarm:** at zero the clock holds, beeps repeat, and a bubble beside the pet offers **Stop**. Clicking the pet also stops it, and it stops on its own after 60 seconds.
- **Right-click menu:** focus and break lengths, pet size, hide pet, reset position, reload sprites, quit.
- **⌃⌥⌘T** shows or hides the pet.
- **Menu bar:** the mode's emoji and time (🔔 while ringing), with Show/Hide pet, focus and break steppers, the upload fields and their status, and Quit.
- **Your own sprites:** drop `idle.png`, `focus.png`, `break.png`, `celebrate.png` or a shared `pet.png` into `~/Library/Application Support/Pomodoro/sprites/`, then choose **Reload sprites**.

See [docs/pet-design.md](docs/pet-design.md) for the full design.

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
- `swift run` and `Pomodoro.app` keep separate settings, because macOS stores them per bundle identifier. They share `sessions.json`, so don't run both at once, or one will overwrite the other's sessions.
- Each build has its own site URL and token, so you enter them once in each. That lets `swift run` send to `http://localhost:3000` while `Pomodoro.app` sends to the deployed site. Each build remembers what it has sent, so the first time a build is set up, it sends everything already in `sessions.json`. The site ignores sessions it already has.
- The upload token is the site's `UPLOAD_TOKEN`. It's stored in UserDefaults, not the Keychain, which is fine because it can only add and delete sessions, never read them.
- The app is ad-hoc signed, not notarized. It's meant for the Mac that built it; a copy downloaded on another Mac will be blocked by Gatekeeper.

## Layout
```
Sources/Pomodoro/
  PomodoroApp.swift    entry point, app delegate, menu bar title
  ContentView.swift    the menu bar dropdown
  PetWindow.swift      the floating pet, its sizes and right-click menu
  PetState.swift       which sprite shows, and loading custom sprites
  TomatoView.swift     the drawn placeholder tomato
  Popout.swift         the panel beside the pet and its tabs
  TimerTab.swift       Focus | Break clock and Google-style editing
  Stopwatch.swift      stopwatch model and tab
  TodayTab.swift       today's sessions
  Bubble.swift         the alarm bubble
  Placement.swift      positions panels beside the pet
  HotKey.swift         the ⌃⌥⌘T global shortcut
  PomodoroTimer.swift  countdown, modes, alarm state, saving runs
  Session.swift        one saved run
  SessionStore.swift   saved runs in sessions.json
  Uploader.swift       sends sessions and deletes to the site
  Phase.swift          modes and duration settings
  Alarm.swift          synthesized beeping alarm
  Notifier.swift       notification banners
build_app.sh           wraps the release build in Pomodoro.app
```
