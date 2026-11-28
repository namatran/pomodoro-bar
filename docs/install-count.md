# Install count (parked)

Parked on 2026-11-28: it's not yet decided whether counting unique installs is worth a prompt and a setting. This note keeps what was built and what's left to decide.

## What it's for
Counting **how many people use the app**, as opposed to how many downloaded it. Each installed copy sends a random ID with its update check, so the website can tell copies apart over time:
- how many copies are installed: distinct IDs
- how many are still in use: IDs seen in the last 30 days
- whether people keep using it: whether IDs from one month still check in the next

It isn't needed for:
- **downloads:** `/download` on the website counts them
- **updates:** each update check already reports the build, so a move from 1.1 to 1.2 shows up without it

Without the ID, the website only has a daily estimate: `visitor` is a hash of IP, user agent and the day, so it can't follow a copy across days or IP changes.

## Where things stand
- **1.2 (released)** sends the ID by default. "Count this install" in the menu bar dropdown turns it off. The live FAQ describes this.
- **Unreleased commits on `main`, after the 1.2 bump:**
  - `bdac863` asks once on first launch ("Help count installs?" with Allow and Don't Allow), and sends nothing until Allow
  - `4d4a747` renames the switch to "Help count installs", off until the prompt is answered
- **pomodoro-web, committed but not pushed:** `a02d164` rewrites the FAQ for the prompt. Push it only together with the release that has the prompt.
- **Website:** the `install` column and the appcast route already accept and store the ID. Rows without one have `install` null.

## Code
- App: `InstallID` and `feedParameters(for:sendingSystemProfile:)` in `Sources/Pomodoro/Updater.swift`, `CountInstallToggle` in `Sources/Pomodoro/ContentView.swift`, the prompt call in `PomodoroApp.swift`
- Website: `app/appcast.xml/route.ts`, `lib/hits.ts`, `supabase/migrations/20261128120000_add_hits_install.sql`

## To pick it back up, choose one
- **Keep it, asking first:** ship the two unreleased commits as 1.3, then push pomodoro-web.
- **Drop it:** make the app stop sending the ID (remove `feedParameters`, the toggle and the prompt), release that, and change the FAQ back to just downloads and builds. 1.2 copies keep sending IDs until they update. Optionally drop the `install` column afterwards.

Until one is picked, 1.2 is live and sends IDs without asking.

## Query
```sql
select count(distinct install) as ever,
       count(distinct install) filter (where at > now() - interval '30 days') as last_30_days
from hits where install is not null;
```
