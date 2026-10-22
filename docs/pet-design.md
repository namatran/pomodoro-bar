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
- A segmented **Focus | Break** picker above an hh:mm:ss display. Like Google, it hides empty leading groups and shrinks as it counts down (`01:00:00` → `59:59`, `01:00` → `59`), but keeps two digits per group. While typing, all six digits show (`00:25:00`). The menu bar title keeps the shorter `25:00`.
- Controls are **Start/Pause** and **Reset**, as on Google's timer. There's no Skip.
- The picker can only be changed while the timer is fresh or has just been reset. After a Reset at zero, it switches Focus ↔ Break by itself, but never starts the next run. Switching modes while typing a time throws the typed time away.
- A hint under the clock:
  - fresh: "Click to type a time"
  - paused: "Click to type a time · ends this run"
  - running: "Click to pause"
  - while typing: "Enter to start · Esc to cancel"

  It's shown in the popout itself, because macOS tooltips usually don't appear for an app that isn't in front.

### Editing the time (like Google)
- Works while the timer is fresh or paused. Clicking a running clock only pauses it, and the next click edits.
- **Clicking the clock** keeps the current time on screen and places a blinking caret at the clicked digit.
- **Moving the caret:** ←/→ move it one digit and skip the colons. Home/End jump to either end.
- **Typing a digit** inserts it at the caret, and the leftmost digit drops off. With the caret at the end, digits push in from the right: `00:12:34` plus `5` gives `01:23:45`.
- **⌫** deletes the digit left of the caret and fills in a `0` on the left.
- **Enter** starts the new time. On a paused run, it first ends and saves the old run (stopped early). If the digits haven't changed, Enter just leaves editing.
- **Start** while typing does the same as Enter, except that with unchanged digits it carries on with the paused run.
- **Esc** or clicking away puts the time back and leaves the run untouched. This differs from Google, whose Esc keeps the edit, because here only Enter or Start may end a run.
- Like Google, `90` in the seconds place means 90 seconds.

### When the clock hits zero
- The alarm rings, the display holds at `00:00:00`, and the sprite celebrates (after focus) or shows the break face (after a break).
- A bubble appears beside the pet on the side with room, saying something like "Focus done! Break next", with a **Stop** button. Clicking the pet while it rings also stops the alarm instead of opening the popout. Neither one records anything. The alarm still stops itself after 60 seconds.
- Until Reset saves the run, it's flagged in red (added 2026-10-22): the popout's clock turns red with a "Reset to save" hint, the menu bar title shows 🔴 in place of the mode's emoji, and the pet gets a red dot. A run under 60 seconds isn't flagged, because Reset won't save it.

### Reset and recording
- **Reset** saves the run if it has at least 60 seconds counted down (not counting pauses), whether or not it reached zero. Anything shorter is thrown away.
- Reset after zero loads the other mode, ready to start but not started. Reset mid-run goes back to the start of the same mode.
- **Quit** saves an unsaved run in the same way. A force-quit or crash loses it.
- Both focus and break runs are saved.

### Stopwatch tab
- **Start/Stop** and **Reset**, with no laps.
- Shown like Google's stopwatch, counting hundredths from `0.00`: `3.25`, then `1:05.25`, then `1:00:05.25`. The leading group isn't padded, and hours keep counting.
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

## Storage
Settled on 2026-10-19, for the second round:
- Every session is kept in `~/Library/Application Support/Pomodoro/sessions.json`, next to the sprites folder. It's a JSON array of records with the fields above and ISO 8601 UTC times. `swift run` and `Pomodoro.app` share this one file.
- Sessions are kept forever. The Today tab shows today's and refreshes at midnight.
- The day isn't stored. Today takes the sessions whose end (`endedAt` for focus, `completedAt` for a break) falls on today in the current local time zone, the same way the site groups them.
- If the file can't be read at launch, it's renamed to `sessions-unreadable-<date>.json` so nothing is lost, and the history starts empty.
- Deleting a row in Today deletes the stored session.
- The old `completedByDay` counts aren't migrated. `PomodoroLog.swift` is removed, and the key is cleared from UserDefaults at launch.

## Upload
Settled on 2026-10-21, for the second round. The site's side is in `~/dev/pomodoro-web/docs/design.md`.
- **Settings:** the dropdown has a site URL field and a token field (hidden as you type), stored in UserDefaults, so `swift run` and `Pomodoro.app` each have their own. The URL is the site's address, such as `http://localhost:3000`; the app adds `/api/sessions` itself, and a trailing slash is fine.
- **What's sent:** every session in `sessions.json` that hasn't been sent yet, including ones saved before the URL and token were set. The app keeps the ids it has sent in UserDefaults, so nothing needs seeding. Each session is POSTed on its own, as the same JSON as `sessions.json`.
- **Deletes:** deleting a row in Today queues a delete for its id in UserDefaults. A delete is only ever sent for a row you deleted, never because a session is missing from the file, so an unreadable `sessions.json` can't empty the site.
- **When:** after each saved session, after each delete, at launch, and when the URL or token changes. Deletes go first. A session saved at Quit has no time to upload, so it goes at the next launch.
- **Answers:** `2xx` means sent. A `400` means the server will never take it, so it's logged and counted as sent, so it's never retried. A wrong token, any other answer, or no network stops the round and leaves the rest waiting for the next one.
- **Status:** a caption under the fields says "All sent", "3 waiting", or "3 waiting · wrong token" (or "can't reach site", or the status code). Without a URL and token, it says "Not set up", with the waiting count.

## Menus
- **Menu bar (slimmed):** the title shows the mode's emoji and time, or 🔔 while the alarm rings. The menu has Show/Hide pet, Focus and Break steppers, the upload fields and status (see Upload), and Quit. The timer controls move to the popout.
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
All stages of the first round are built:
1. Stage 1 and stage 2: pet window, sprites, popout, Google-style rules, Stopwatch, Today.
2. Stage 2b: Focus | Break model, Google-style editing and hint, break rows in Today, slimmed steppers.
3. Stage 3: alarm bubble, right-click menu, hotkey, slimmed menu bar.

Details settled while building stage 3:
- Pet sizes are 72, 96 and 128pt, with Medium as the default. Resizing keeps the pet's bottom centre in place.
- The popout and the bubble both want the side with room, so while the popout is open the bubble stacks above it, or below it near the top of the screen.
- Hiding the pet also hides the popout and bubble, and it stays hidden after a relaunch. Showing it brings back whichever were up.
- The hotkey uses Carbon's `RegisterEventHotKey`, which needs no Accessibility permission.

## Known bug (postponed)
A `swift run` crashed with:

```
SwiftUI/Button.swift:808: Fatal error: Incorrect actor executor assumption; Expected same executor as MainActor.
```

The process exited with code 133, a Swift runtime trap. The toolchain is Swift 6.4 while `Package.swift` declares tools-version 5.9. The trigger hasn't been identified; the owner doesn't remember what they clicked. The likeliest suspect was pressing Return on the menu bar's "Stop alarm" button (`.keyboardShortcut(.defaultAction)`), which the slimmed menu bar has now removed. Fix it in its own `fix:` commit if it happens again.
