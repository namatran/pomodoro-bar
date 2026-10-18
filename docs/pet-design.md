# Pet design

A desktop pet that floats on screen, owns the timer, and shows today's sessions. Every question below was settled in grilling sessions on 2026-10-18. The menu bar item stays, but in a slimmer form.

The app started as a Pomodoro timer and is now closer to a **focus tracker with a Break mode**: one Google-style timer, where every focus run of a minute or more is saved, plus a Break mode for timing breaks. There are no long breaks and no 4-run cycle.

## Scope of the first round
- Build the UI with mock data. The timer, stopwatch and alarm are real. The Today tab reads from one `MockToday` source, and saved runs are added to that list in memory so recording can be seen working.
- Saving sessions for real (replacing the per-day counts in `PomodoroLog.swift`) comes in a later round, when the data is connected. After that come the website steps and the app's upload.
- Keep the implementation clean and simple.

## Architecture
- The pet is a floating window inside this Swift app, not a Hammerspoon pet. The app already has the timer, alarm, notifications, settings and log, so they are reused, and there is no state file or second process.
- It doesn't work with organizepet's pet bus. organizepet isn't installed, and a small Hammerspoon shim that calls the app can be added later if needed.

## References
- `costpriority` (`~/dev/costpriority`, installed at `~/.hammerspoon/cost`) is **MIT**. Its code can be reused if the copyright notice is kept. It's the model for the popout and the settings menu.
- `claudeaiagentreminderguy` (installed at `~/.hammerspoon/claudepet`) has **no licence**, so all rights are reserved. Use it as a visual and behavioural reference only (bubbles, dragging, the hotkey), and don't copy its code.
- Google's timer is the model for the Timer and Stopwatch tabs, including how editing works (checked in Chrome on 2026-10-18).
- Pomofocus has Pomodoro | Short Break | Long Break tabs. It was considered and rejected in favour of Focus | Break.

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
  - **celebrate**, shown while the alarm rings after a focus run
- The sprite shows the first match in this order:
  1. Alarm ringing: celebrate after focus, or break after a break.
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
- A segmented **Focus | Break** picker above a `00:00:00` (hh:mm:ss) display. The menu bar title keeps the shorter `25:00`.
- Controls are **Start/Pause** and **Reset**, as on Google's timer. There's no Skip.
- The picker can only be changed while the timer is fresh or has just been reset. After a Reset at zero, it switches Focus ↔ Break by itself, but never starts the next run.
- A hint under the clock:
  - fresh: "Click to type a time"
  - paused: "Click to type a time · ends this run"
  - running: "Pause to change the time"
  - while typing: "Enter to start · Esc to cancel"

  It's shown in the popout itself, because macOS tooltips usually don't appear for an app that isn't in front.

### Editing the time (like Google)
- Works while the timer is fresh or paused, not while running.
- **Clicking the clock** keeps the current time on screen and places a blinking caret at the clicked digit.
- **Moving the caret:** ←/→ move it one digit and skip the colons. Home/End jump to either end.
- **Typing a digit** inserts it at the caret, and the leftmost digit drops off. With the caret at the end, digits push in from the right: `00:12:34` plus `5` gives `01:23:45`.
- **⌫** deletes the digit left of the caret and fills in a `0` on the left.
- **Enter** starts the new time. On a paused run, it first ends and saves the old run (stopped early). If the digits haven't changed, Enter just leaves editing.
- **Esc** or clicking away puts the time back and leaves the run untouched. This differs from Google, whose Esc keeps the edit, because here only Enter may end a run.
- Like Google, `90` in the seconds place means 90 seconds.

### When the clock hits zero
- The alarm rings, the display holds at `00:00:00`, and the sprite celebrates (after focus) or shows the break face (after a break).
- A bubble appears beside the pet on the side with room, saying something like "Focus done! Break next", with a **Stop** button. Clicking the pet while it rings also stops the alarm instead of opening the popout. Neither one records anything. The alarm still stops itself after 60 seconds.

### Reset and recording
- **Reset** saves the run if it has at least 60 seconds counted down (not counting pauses), whether or not it reached zero. Anything shorter is thrown away.
- Reset after zero loads the other mode, ready to start but not started. Reset mid-run goes back to the start of the same mode.
- **Quit** saves an unsaved run in the same way. A force-quit or crash loses it.
- Both focus and break runs are saved.

### Stopwatch tab
- **Start/Stop** and **Reset**, shown as `00:00:00` with no laps or centiseconds.
- Runs independently of the timer and is never recorded.

### Today tab
- Header: today's 🍅 count and focus total. Breaks don't count toward either.
- Focus rows show start → reset (`9:32 → 10:02`), with a second line of "finished at 9:58" or "stopped early".
- Break rows are dimmer: `☕ 10:02 → 10:07` (start → end).
- Clicking a row selects it and shows a ⌫ button at its right edge. Clicking ⌫ or pressing the ⌫ key deletes it immediately. Clicking elsewhere deselects it.

## Session record
This replaces the shape that was first agreed with the website:
- `id`: generated by the app
- `kind`: `focus` or `break`
- `startedAt`: UTC, the first start of the run
- `completedAt`: UTC
  - focus: when the clock hit zero, or empty if stopped early
  - break: when the clock hit zero, or when Reset was pressed if cut short
- `endedAt`: UTC, focus only. When Reset or Quit saved the run. Breaks don't have one.
- `durationSeconds`: time counted down, not counting pauses

A session belongs to the day it ended.

## Menus
- **Menu bar (slimmed):** the title shows the mode's emoji and time, or 🔔 while the alarm rings. The menu has Show/Hide pet, Focus and Break steppers, and Quit. The timer controls move to the popout.
- **Pet's right-click menu** (a native menu):
  - Focus length ▸ 15/20/25/30/45/50/60
  - Break length ▸ 5/10/15/20
  - Pet size ▸ Small/Medium/Large
  - Hide pet ⌃⌥⌘T
  - Reset position
  - Reload sprites
  - Quit

  The length submenus show the current value checked, even if it's a custom one from the stepper.

## Website
See `~/dev/pomodoro-web/docs/design.md`. It needs these changes:
- Runs of at least 60s are logged whether or not they finished.
- Rows have a `kind`, and `ended_at` is empty for breaks.
- `completed_at` is added.
- Break rows are shown dimmer, and day counts and totals stay focus-only.
- The upload token can also delete a session by its id, but still never read. The app queues deletions like failed uploads.

A visual redesign of the site is a separate future task.

## Build order
Stage 1 and stage 2 (pet window, sprites, popout, Google-style rules, Stopwatch, Today) are built. Next:
1. Stage 2b: Focus | Break model, Google-style editing and hint, break rows in Today, slimmed steppers.
2. Stage 3: alarm bubble, right-click menu, hotkey, slimmed menu bar.

## Known bug (postponed)
A `swift run` crashed with:

```
SwiftUI/Button.swift:808: Fatal error: Incorrect actor executor assumption; Expected same executor as MainActor.
```

The process exited with code 133, a Swift runtime trap. The toolchain is Swift 6.4 while `Package.swift` declares tools-version 5.9. The trigger hasn't been identified; the owner doesn't remember what they clicked. The likeliest suspect is pressing Return on the menu bar's "Stop alarm" button (`.keyboardShortcut(.defaultAction)`), which the slimmed menu bar removes. Fix it in its own `fix:` commit if it happens again.
