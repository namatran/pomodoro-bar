# Install count

Decided on 2026-11-28: keep counting unique installs, but ask first. 1.3 ships the prompt.

## What it's for
Counting **how many people use the app**, as opposed to how many downloaded it. Each installed copy sends a random ID with its update check, so the website can tell copies apart over time:
- how many copies are installed: distinct IDs
- how many are still in use: IDs seen in the last 30 days
- whether people keep using it: whether IDs from one month still check in the next

It isn't needed for:
- **downloads:** `/download` on the website counts them
- **updates:** each update check already reports the build, so a move from 1.1 to 1.2 shows up without it

Without the ID, the website only has a daily estimate: `visitor` is a hash of IP, user agent and the day, so it can't follow a copy across days or IP changes.

## How it works
- **1.3 and later** ask once on first launch ("Help count installs?" with Allow and Don't Allow) and send nothing until Allow. "Help count installs" in the menu bar dropdown changes the answer later.
- **1.2** sent the ID by default, with a "Count this install" switch to turn it off. Those copies keep sending IDs until they update.
- **pomodoro-web:** `d980e1e` reverts `322248f`, so the FAQ and README describe the prompt again. Push it with the 1.3 release.
- **Website:** the `install` column and the appcast route accept and store the ID. Rows without one have `install` null.

## Code
- App: `InstallID` and `feedParameters(for:sendingSystemProfile:)` in `Sources/Pomodoro/Updater.swift`, `CountInstallToggle` in `Sources/Pomodoro/ContentView.swift`, the prompt call in `PomodoroApp.swift`
- Website: `app/appcast.xml/route.ts`, `lib/hits.ts`, `supabase/migrations/20261128120000_add_hits_install.sql`

## Query
```sql
select count(distinct install) as ever,
       count(distinct install) filter (where at > now() - interval '30 days') as last_30_days
from hits where install is not null;
```
