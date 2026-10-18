# Pet design (in progress)

A desktop pet that sits on screen as a companion to the menu bar timer and shows today's focus sessions. This doc records what has been decided and what is still open. Keep grilling on the open questions before building anything.

## Decided
- **Role:** a companion to the menu bar timer, not a replacement. The timer and its controls stay in the menu bar, and the pet reacts to the timer's state.
- **Art:** a placeholder tomato for now. The owner will draw their own doodles later, so sprites must be easy to swap. This may also lead to UI changes in the menu bar app later. That's out of scope for now.
- **References:**
  - `costpriority` (`~/dev/costpriority`, github.com/mattypark/costpriority) is **MIT**. Its code can be reused if the copyright notice is kept.
  - `claudeaiagentreminderguy` (github.com/mattypark/claudeaiagentreminderguy) has **no licence**, so all rights are reserved. Use it as a visual and behavioural reference only, and don't copy its code.
- **Website:** it stays (see `~/dev/pomodoro-web/docs/design.md`). The pet covers today, and the site covers history and other devices.

## Facts about the environment
- Hammerspoon is installed and running. `~/.hammerspoon/init.lua` loads `claudepet` and `cost` with plain `require`.
- `organizepet` isn't installed. If the pet is built for Hammerspoon, it should still work with organizepet's pet bus (`show`, `hide` and `isHidden` actions) so it can be hidden alongside the other pets later.
- The app keeps only per-day counts today (`PomodoroLog.swift`). There are no per-session records or start times yet.

## Open questions (with recommendations)
1. **Where is the pet built?**
   - (a) A Hammerspoon pet (`~/.hammerspoon/pomopet/`) adapted from cost, which watches a JSON file that the app writes on every state change.
   - (b) A floating window inside the Swift app.

   *Recommended: (a).* It matches the other two pets and works with organizepet. The JSON file is a small, clear contract between the app and the pet. The cost is a second language (Lua) and a second process.
2. **Build order.** *Recommended:* first the per-session records in the app, then the pet, then website steps 3–5, then the app's upload.
3. **Which states does the pet react to?** Idle, focusing, paused, on a break, alarm ringing, and just completed a session. *Recommended:* all of them, drawn as four sprites: idle (also used for paused), focus, break and celebrate, with the alarm shown as a speech bubble. Each state reads its own file, such as `assets/focus.png`, and falls back to a shared `pet.png` so doodles can be added one at a time.
4. **What does clicking the pet show?**
   - (a) Today only: the count, total focus time, and the list of sessions with their times and lengths.
   - (b) (a) plus the live timer and controls.

   *Recommended: (a).*

Further questions follow from the answers to these, such as where the pet's source code lives and the exact JSON shape.

## Shared with the website
The per-session records the app keeps must match the website's session shape so the upload can use them unchanged:
- an `id` the app generates
- `startedAt`: UTC, the first start of the focus phase, cleared on reset or skip
- `endedAt`: UTC, when the clock reached zero
- `durationSeconds`: focus time counted down, not counting pauses

Only naturally completed focus sessions are recorded. The upload queue and settings fields (website step 6) are built later, on top of these records.

## Known bug: fix before building on the app
A `swift run` crashed with:

```
SwiftUI/Button.swift:808: Fatal error: Incorrect actor executor assumption; Expected same executor as MainActor.
```

The process exited with code 133, a Swift runtime trap. The toolchain is Swift 6.4 while `Package.swift` declares tools-version 5.9, and the newer runtime adds this kind of main-actor check. The trigger hasn't been identified yet. Ask the owner what they clicked or pressed when it crashed (for example the Return key on "Stop alarm"). Fix it in its own `fix:` commit.
