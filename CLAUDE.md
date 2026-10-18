# Pomodoro menu bar app

SwiftUI `MenuBarExtra` app in a Swift Package (no Xcode project; Command Line Tools only).

## Commands
- Build: `swift build`
- Run: `swift run`
- Bundle as .app (menu bar only, no Dock icon): `./build_app.sh && open Pomodoro.app`

## Workflow
- Make small, logical commits using Conventional Commits (`type: description`, no trailing period).
- The user runs builds in their own terminal; do not run `swift build` or `swift run` unless asked.
- Work in stages of a few commits. Stop and summarise at the end of each stage (so the user can build and check it), or sooner if a decision is needed.
- Never push. Do not create remotes.
