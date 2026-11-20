# Pomodoro

A focus timer with a desktop pet, for macOS. A small tomato floats on screen and owns the timer, with a slim menu bar item alongside. Built with SwiftUI and AppKit as a Swift Package, so it builds with the Command Line Tools alone (no Xcode).

## Features
- **Pet:** a floating, draggable tomato that bobs gently, shows a face for each state (idle, focus, break, celebrate), and stays on every Space, including over full-screen apps. It remembers where you put it.
- **Popout:** click the pet for a frosted panel with three tabs:
  - **Timer:** Focus | Break modes, Start/Pause and Reset, like Google's timer. Click the clock to type a time; click a running clock to pause it first.
  - **Stopwatch:** counts hundredths, like Google's stopwatch.
  - **Today:** today's sessions and focus total. Click a row and press ⌫ to delete it. **See all** opens the window.
- **Window:** in the website's glass look, following light and dark mode: the same Focus | Break timer as the pet's, the last focus session (start, end, focus time, and any pause, with the tomato saying when it ended), then every day as a card that opens and closes, with its focus count and total. Delete rows the same way as in Today, or click a row's pencil to edit it: Focus or Break, start and end, and the length (time focused, not counting pauses). While it's open, Pomodoro shows in the Dock and ⌘Tab; close it and the app goes back to the menu bar only. Open it from Spotlight, **Open Pomodoro** in the menu bar dropdown or the pet's right-click menu, or Today's **See all**.
- **Recording:** Reset saves any run of 60 seconds or more, focus or break, finished or not. Quit saves an unsaved run too. Sessions are kept in `~/Library/Application Support/Pomodoro/sessions.json`.
- **Alarm:** at zero the clock holds, beeps repeat, and a bubble beside the pet offers **Stop**. Clicking the pet also stops it, and it stops on its own after 60 seconds. Until **Reset** saves the run, the clock is red, the menu bar shows 🔴, and the pet wears a red dot.
- **Right-click menu:** open Pomodoro, focus and break lengths, pet size, hide pet, reset position, reload sprites, quit.
- **⌃⌥⌘T** shows or hides the pet.
- **Opening it again**, say from Spotlight, shows the pet if it's hidden and opens the window.
- **Menu bar:** the mode's emoji and time (🔔 while ringing), with Open Pomodoro, Show/Hide pet, focus and break steppers, Open at login, and Quit.
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

To build the menu-bar-only app (no Dock icon) with notifications and the tomato icon:

```bash
./build_app.sh
```

It quits the running copy (which saves an unsaved run), installs the new build as `/Applications/Pomodoro.app`, and opens it, so Spotlight always finds the latest one. The first time, macOS asks whether your terminal may control Pomodoro; that's the quit.

To start it at login, turn on **Open at login** in the menu bar dropdown.

## Notes
- Notification banners need the app bundle. `swift run` still plays the alarm but skips the banner.
- `swift run` and `Pomodoro.app` keep separate settings, because macOS stores them per bundle identifier. They share `sessions.json`, so don't run both at once, or one will overwrite the other's sessions.
- Sessions used to be uploaded to the [pomodoro-web](../pomodoro-web) site. That was removed on 2026-10-24; the history now lives only in the app.
- The app is ad-hoc signed, not notarized. It's meant for the Mac that built it; a copy downloaded on another Mac will be blocked by Gatekeeper.

## Layout
```
Sources/Pomodoro/
  PomodoroApp.swift    entry point, app delegate, menu bar title
  AppIcon.swift        the app icon, rendered from the tomato
  ContentView.swift    the menu bar dropdown and Open at login
  PetWindow.swift      the floating pet, its sizes and right-click menu
  PetState.swift       which sprite shows, and loading custom sprites
  TomatoView.swift     the drawn placeholder tomato
  Popout.swift         the panel beside the pet and its tabs
  TimerTab.swift       Focus | Break clock and Google-style editing
  Stopwatch.swift      stopwatch model and tab
  TodayTab.swift       today's sessions
  SessionRow.swift     one session row, shared by Today and the window
  AppWindow.swift      the app window: timer, last session, empty state
  DayCard.swift        one day's card and table in the window
  Glass.swift          the site's colours, glass pane, bubble and pill buttons
  Bubble.swift         the alarm bubble
  Placement.swift      positions panels beside the pet
  HotKey.swift         the ⌃⌥⌘T global shortcut
  PomodoroTimer.swift  countdown, modes, alarm state, saving runs
  Session.swift        one saved run
  SessionStore.swift   saved runs in sessions.json
  Phase.swift          modes and duration settings
  Alarm.swift          synthesized beeping alarm
  Notifier.swift       notification banners
build_app.sh           wraps the release build in Pomodoro.app and installs it
```
