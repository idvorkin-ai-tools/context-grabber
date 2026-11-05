# Grabber Native on the Mac

Igor, 2026-11-03 ([#638](https://github.com/idvorkin/context-grabber/issues/638)): *"Build catalyst as well."* The
same app as a real Mac app, rung 2 of the issue: one code base, not a Mac-only rewrite. This is the native app's spec;
`2026-05-23-mac-catalyst-support-design.md` is the React Native app's, kept for history.

## Summary

Grabber Native opens on a Mac in a resizable window, with the iPad's layout. What a Mac can do works the way it does on
an iPad: chat, the whiteboard, the Cockpit page, the timer's clock, breathing, the card. What a Mac can't do says so or
doesn't show, and never crashes. An iPhone and an iPad change in no way at all.

## Goals

- Igor can run the app on his Mac with one command.
- Chat and the whiteboard work on the Mac as soon as it opens, against Igor's own Cockpit, as on his phone.
- Nothing a Mac lacks can take the app down, or read as something broken that could be fixed.
- A test launch can keep away from Larry by naming a stand-in or nowhere.

## Non-goals

- Menu commands, other keyboard shortcuts, a Mac sidebar, a Mac look. A later piece of work.
- A file finder. It prompted the issue, and it is a different app.
- Widgets and the share sheet on the Mac (below).
- Anything on an iPhone or an iPad.

## What Igor sees

**Starting it.** One command builds and opens the app. It carries no iCloud and no Health, because those need a signed
build. With no address named it reaches Igor's Cockpit; a run can name a stand-in, or nowhere.

**Which Cockpit.** Igor's Mac is his own machine on his tailnet, and having to name his own Cockpit on it read as a
broken app (#680, reversing the first rule here). So a Mac build behaves as his phone does: with no address named, chat,
the Inbox, the whiteboard's turns, the Cockpit page, the usage strip and a call all reach his Cockpit. A message sent
from the Mac is a real message to Larry.

A launch can name another address, for chat and a call, for the page and for the usage strip; the one-command run names
all of them at once, and a launch that names only some leaves the rest on Igor's Cockpit:

- Named a stand-in, it talks only to the stand-in.
- Named nowhere, nothing leaves the Mac for any Cockpit. Chat and the page say copyably that there is no address, as a
  simulator's chat does, a call ends with its usual copyable reason, and the usage strip isn't drawn.

This is how a test launch stays out of Igor's threads: **a test launch must name one or the other.**

**The outbox.** A launch on Igor's own Cockpit and a launch named anywhere else keep separate outboxes. A message a test
launch leaves waiting never goes to Larry on a later plain launch: it waits for a later test launch, and goes to the
address that one names. A real message left waiting never goes to a stand-in: it waits for a launch on Igor's Cockpit.

The stats archive and a call's log still send nothing, ever, unless a launch names an archive; the Mac has no Health to
archive. On a phone and an iPad nothing changes. A simulator is unchanged too: its chat reaches only what it is pointed at.

**Health.** A Mac has no Health store. Today says so in one quiet line, *Health lives on your phone. This Mac has none.*,
where the cards would be: no error, nothing to copy, and no *pull to grab* (Igor, 2026-11-06, #700: the error on every
grab read as if something had broken). Pulling to grab again changes nothing. The rest of the app carries on, and box
breathing saves no Mindful Minutes. A phone or iPad that can't reach Health still shows the copyable error.

**Places.** The map, the known places and an imported trail work, and "where am I" works if macOS grants location.
Nothing records in the background on a Mac: where the switch would be, a line says so.

**The Live Activity and widgets.** Not on a Mac. The timer and a call run in the window alone, and nothing about them
reports a failure.

**The share sheet.** The Mac's Share menu doesn't offer Grabber Native. Chat's own outbox works without it: a message
written on the Mac waits on the Mac until it goes.

**iCloud.** In the build the command makes, whiteboards stay on the Mac, the daily strip doesn't sync, and a problem
report stays in the app's folder. The whiteboard says its sync is off, as in any build without it. A build signed with
Igor's team has iCloud too.

**Enter sends** (#683). Wherever the app asks Igor to type and then confirm, Enter or Command+Enter confirms, on the Mac:
chat's bar (where Shift+Enter is a new line, see the chat spec), renaming a board, adding a place, and naming one. A
problem report's note keeps Enter for a new line, because it is a long note, and sends with Command+Enter, as the report
dialog already does. A key confirms only what the button would: a form missing what it needs stays as it is.

**Background work.** A Mac runs no background tasks for the app. While the window is open chat keeps itself up to date;
when the app is quit nothing runs, and that isn't an error.

## Acceptance

- The app opens on Igor's Mac, and each home tile either opens its screen or says why it can't.
- With no address named, chat, the Cockpit page and the usage strip reach Igor's Cockpit, with no error shown.
- Named nowhere, no connection to the real Cockpit is made, on any route.
- With a stand-in named, a message sent in Chat reaches the stand-in and its reply shows.
- A message left waiting by a test launch is not sent by a later plain launch, and one left waiting by a plain launch is
  not sent by a later test launch.
- A phone and an iPad simulator build still compile, and their behaviour is untouched.

## Later

Menu commands and keyboard shortcuts, window sizes and a Mac sidebar, the iPad's "New window" as a Mac menu item, a
signed build that carries iCloud, widgets on the Mac's desktop, and the share extension.
