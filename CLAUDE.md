# Pomodoro menu bar app

SwiftUI `MenuBarExtra` app in a Swift Package (no Xcode project; Command Line Tools only).

## Commands
- Build: `swift build`
- Run: `swift run`
- Bundle as .app (menu bar only, no Dock icon): `./build_app.sh && open Pomodoro.app`

## Workflow
- One feature per commit, Conventional Commits (`feat: add ...`, no trailing period).
- The user runs builds in their own terminal; do not run `swift build` or `swift run` unless asked.
- After each commit, stop and summarise what changed.
- Do not push or create remotes unless asked.
