# Pet design

A desktop pet that floats on screen, owns the Pomodoro timer, and shows today's focus sessions. Every question below was settled in a grilling session on 2026-10-18. The menu bar item stays, but in a slimmer form.

## Scope of the first round
- Build the UI with mock data. The timer, stopwatch and alarm are real. The Today tab reads from one `MockToday` source, and Reset adds sessions to that list in memory so recording can be seen working.
- Saving sessions for real (replacing the per-day counts in `PomodoroLog.swift`) comes in a later round, when the data is connected. After that come the website steps and the app's upload.
- Keep the implementation clean and simple.

## Architecture
- The pet is a floating window inside this Swift app, not a Hammerspoon pet. The app already has the timer, alarm, notifications, settings and log, so they are reused, and there is no state file or second process.
- It doesn't work with organizepet's pet bus. organizepet isn't installed, and a small Hammerspoon shim that calls the app can be added later if needed.

## References
- `costpriority` (`~/dev/costpriority`, installed at `~/.hammerspoon/cost`) is **MIT**. Its code can be reused if the copyright notice is kept. It's the model for the popout and the settings menu.
- `claudeaiagentreminderguy` (installed at `~/.hammerspoon/claudepet`) has **no licence**, so all rights are reserved. Use it as a visual and behavioural reference only (bubbles, dragging, the hotkey), and don't copy its code.
- Google's timer is the model for the Timer and Stopwatch tabs.

## Pet window
- About 96pt wide, with a gentle bob like cost and claudepet.
- Draggable. A movement under 4px counts as a click. Its position is saved, and it first appears at the bottom right of the main screen, clear of cost and claudepet.
- Floats above normal windows on every Space, including over full-screen apps, because the menu bar is hidden there.
- ⌃⌥⌘T shows or hides it. claudepet already uses ⌃⌥⌘P and cost uses ⌃⌥⌘I.

## Sprites
- Four states:
  - **idle**, also used for paused
  - **focus**
  - **break**
  - **celebrate**, shown while the alarm rings after a focus phase
- The sprite shows the first match in this order:
  1. Alarm ringing: celebrate after a focus phase, or break after a break.
  2. Timer running: focus or break.
  3. Stopwatch running: focus.
  4. Otherwise idle.
- Placeholder: a flat, cute tomato drawn in SwiftUI code with a different face for each state, so no resources need bundling.
- Your own doodles: put `idle.png`, `focus.png`, `break.png`, `celebrate.png` or a shared `pet.png` into `~/Library/Application Support/Pomodoro/sprites/`. The app looks for the state's file, then `pet.png`, then falls back to the drawn tomato. "Reload sprites" picks up new files without relaunching.

## Popout
- Clicking the pet opens it beside the pet, on the side with more room, and clamped to stay on screen, as cost's board does. It stays open, follows the pet when dragged, updates live, and closes on a second click or its ✕. It doesn't close on outside clicks.
- Look: native macOS material (frosted, following light and dark mode) with rounded corners. The alarm bubble looks the same.
- Tabs: **Timer** (open by default), **Stopwatch**, **Today**.

### Timer tab
- A segmented phase picker, **Focus | Short | Long**, above a `00:00:00` (hh:mm:ss) display. The menu bar title keeps the shorter `25:00`.
- Controls are **Start/Pause** and **Reset**, as on Google's timer. There's no Skip; the phase picker covers it.
- Typed entry works while the timer is fresh or has just been reset. Click the display, type digits that fill in from the right (`2` `5` `0` `0` gives `00:25:00`), then press Enter to start or Esc to cancel. The typed length applies to this run only. While paused mid-run, only Resume and Reset are offered.
- Changing the phase picker also works only while the timer is fresh or reset. After a Reset at zero, it selects the next phase automatically: a short break, or a long break every 4th focus.

### When the clock hits zero
- The alarm rings, the display holds at `00:00:00`, and the sprite celebrates (after a focus phase).
- A bubble appears beside the pet on the side with room, saying something like "Focus done! Break next", with a **Stop** button. Clicking the pet while it rings also stops the alarm instead of opening the popout. Neither one records anything. The alarm still stops itself after 60 seconds.

### Reset and recording
- **Reset** saves the focus run. It records a session if the run has at least 60 seconds of focus counted down (not counting pauses), whether or not it reached zero. Anything shorter is thrown away.
- Reset after zero loads the **next** phase, ready to start but not started. Reset mid-run goes back to the start of the **same** phase.
- **Quit** records an unsaved focus run in the same way. A force-quit or crash loses it.
- Breaks are never recorded.

### Stopwatch tab
- **Start/Stop** and **Reset**, shown as `00:00:00` with no laps or centiseconds.
- Runs independently of the timer and is never recorded.

### Today tab
- Shows today's count, total focus time, and the list of sessions. Early-stopped sessions count toward the totals and are marked "stopped early".
- Each row shows start, the time it hit zero, and the reset time. The exact layout will be decided once the UI is built.
- Clicking a row selects it and shows a ⌫ button at its right edge. Clicking ⌫ or pressing the ⌫ key deletes it immediately. Clicking elsewhere deselects it.

## Session record
This replaces the shape that was first agreed with the website:
- `id`: generated by the app
- `startedAt`: UTC, the first start of the focus run
- `completedAt`: UTC, when the clock hit zero, or empty if stopped early
- `endedAt`: UTC, when Reset or Quit saved the run
- `durationSeconds`: focus time counted down, not counting pauses

A session belongs to the day it ended.

## Menus
- **Menu bar (slimmed):** the title shows the phase emoji and time, or 🔔 while the alarm rings. The menu has Show/Hide pet, the three duration steppers, and Quit. The timer controls move to the popout.
- **Pet's right-click menu** (a native menu):
  - Focus length ▸ 15/20/25/30/45/50/60
  - Short break ▸ and Long break ▸, with presets in the same way
  - Pet size ▸ Small/Medium/Large
  - Hide pet ⌃⌥⌘T
  - Reset position
  - Reload sprites
  - Quit

  The duration submenus show the current value checked, even if it's a custom one from the stepper.

## Website
See `~/dev/pomodoro-web/docs/design.md`. It needs these changes:
- Early-stopped sessions of at least 60s are logged.
- `ended_at` becomes when the run was saved.
- `completed_at` is added.
- The upload token can also delete a session by its id, but still never read. The app queues deletions like failed uploads.

A visual redesign of the site is a separate future task.

## Build order (this round)
One small `feat:` commit each:
1. Pet window
2. Sprites
3. Popout with the Timer tab
4. Stopwatch tab
5. Today tab
6. Alarm bubble
7. Right-click menu
8. Hotkey
9. Slimmed menu bar

## Known bug (postponed)
A `swift run` crashed with:

```
SwiftUI/Button.swift:808: Fatal error: Incorrect actor executor assumption; Expected same executor as MainActor.
```

The process exited with code 133, a Swift runtime trap. The toolchain is Swift 6.4 while `Package.swift` declares tools-version 5.9. The trigger hasn't been identified; the owner doesn't remember what they clicked. The likeliest suspect is pressing Return on the menu bar's "Stop alarm" button (`.keyboardShortcut(.defaultAction)`), which the slimmed menu bar removes. Fix it in its own `fix:` commit if it happens again.
