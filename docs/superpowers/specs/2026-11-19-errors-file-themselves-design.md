# An error on screen files a report by itself

Status: decided by Igor on 2026-11-14 (idvorkin/bug-kit#119), for #876. Stories 155–157.

## The idea in one line

Every error Grabber Native shows, in the app or in the share sheet, reaches the Mac as an automatic report without
anyone copying it, once per kind of error every 10 minutes.

## Why

Igor, from the iPad (#876): "Failures anywhere should auto log bugs. E.g., if you didn't get this bug from the [share]
sheet that should've auto logged." He had copied the share sheet's dictation error and filed it by hand. Most errors
he sees, he does not have time to report, so they are never fixed.

## What happens

- **An error appears.** Any error on screen with its Copy error button (every user-visible error in the app is one)
  saves an automatic report when it first shows: no dialog, no screenshot, and nothing on screen changes. The report
  says what Copy error would have copied (the message, where it happened, the build and the state), which screen it
  was on, the session log, and what was on screen (its accessibility tree). The Mac's listener files it as an
  *Automatic report: <where it happened>* issue, labelled `auto`, like the call's automatic reports.
- **The same error again.** Each kind of error (where it happened, the context Copy error shows, such as sending a
  chat message) files at most once every 10 minutes, even across a relaunch. A repeat is noted in the session log and files nothing.
- **Errors that are expected file nothing.** They still show, with Copy error, exactly as before:
  - every error shown while the phone has no network: offline, a failed send or load is expected, not a bug;
  - *Health is not available on this device*: the device has no Health, which no fix can change.
- **The share sheet.** An error on the share card (its dictation's, say) files too. The share sheet is its own small
  program with no network of its own, so it keeps the report in the space it shares with the app; the next time the
  app opens or comes to the front, the app takes the report and sends it to the Mac through iCloud like its own. The
  share sheet keeps its own session log there too, so the report carries what the share card did.

## Not in this change

- The share card's two older error lines (what was shared could not be read; the Inbox could not be written) keep
  their own Copy button; they become Copy error problems, and so file themselves, in a change of their own.
- A switch to turn self-filing off. Igor asked for every error.

## Acceptance

- An error on screen in the app saves one automatic report for its kind of error; the session log has
  `bug_report_auto` with that kind as its reason.
- The same kind again within 10 minutes saves nothing; the log has `bug_report_auto_skipped`.
- An error shown while offline, or *Health is not available*, saves nothing; the log has `bug_report_auto_skipped`
  with `auto_file: false`.
- An error on the share card is saved in the shared space; the app's next launch or foreground takes it into its own
  reports (`bug_report_adopted` in the app's log), and it is queued for iCloud like any report.
