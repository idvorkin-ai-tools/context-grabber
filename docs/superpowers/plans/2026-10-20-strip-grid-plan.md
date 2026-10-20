# Issue 414: two-week strip editor

Use a platform-free CheckFortnight snapshot for fourteen calendar days, display labels, saved and staged marks,
automatic evidence, summary text and changed-day diff. DailyStripModel gathers the same automatic sources as the
strip, and saves the diff through DailyStrip.set and StripCloudSync.changed, refreshing once afterward.
DailyStripView renders the snapshot with local State, tile identifiers and a Done action. Failed loads or saves
show BugProblemView with operation and day state; failed saves keep the editor open. Host tests cover calendar
boundaries, staging, summaries, automatic evidence and peer unmarks. Update UI tests without running them.
