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
- Chat and the whiteboard work on the Mac once it is pointed at a Cockpit.
- Nothing a Mac lacks can take the app down, or read as something broken that could be fixed.
- A Mac launch can never talk to the real Cockpit or to Larry by accident.

## Non-goals

- Menu commands, keyboard shortcuts, a Mac sidebar, a Mac look. A later piece of work.
- A file finder. It prompted the issue, and it is a different app.
- Widgets and the share sheet on the Mac (below).
- Anything on an iPhone or an iPad.

## What Igor sees

**Starting it.** One command builds and opens the app. It carries no iCloud and no Health, because those need a signed
build. With no address named it reaches no Cockpit; a run can name a stand-in or the real one.

**Which Cockpit.** A Mac reaches the tailnet just as a simulator does, so a Mac build follows the simulator's rule
(chat spec, *On a simulator*) and goes further. With no address, nothing leaves the Mac for any Cockpit:

- Chat, the Inbox and the whiteboard's turns reach none, and the chat list and an open thread say copyably that this Mac
  build has no address and how to give it one. What is waiting stays waiting.
- The Cockpit page shows its "Can't reach" panel with the copyable error, saying this Mac build has no address and how
  to give it one, rather than asking about Tailscale.
- The usage strip isn't drawn, as off the tailnet.
- A call can't connect, and ends with its usual copyable reason.
- The stats archive and a call's log send nothing, ever, unless a launch names an archive.

A launch that names the real Cockpit is the only way a Mac build reaches it. On a phone and an iPad nothing changes; a
simulator's Cockpit page, usage strip and call are as they were.

**Health.** A Mac has no Health store. Today says Health isn't available, as it does on any device without one, and the
rest of the app carries on. Box breathing saves no Mindful Minutes.

**Places.** The map, the known places and an imported trail work, and "where am I" works if macOS grants location.
Nothing records in the background on a Mac: where the switch would be, a line says so.

**The Live Activity and widgets.** Not on a Mac. The timer and a call run in the window alone, and nothing about them
reports a failure.

**The share sheet.** The Mac's Share menu doesn't offer Grabber Native. Chat's own outbox works without it: a message
written on the Mac waits on the Mac until it goes.

**iCloud.** In the build the command makes, whiteboards stay on the Mac, the daily strip doesn't sync, and a problem
report stays in the app's folder. The whiteboard says its sync is off, as in any build without it. A build signed with
Igor's team has iCloud too.

**Background work.** A Mac runs no background tasks for the app. While the window is open chat keeps itself up to date;
when the app is quit nothing runs, and that isn't an error.

## Acceptance

- The app opens on Igor's Mac, and each home tile either opens its screen or says why it can't.
- With no address named, no connection to the real Cockpit is made, on any route.
- With a stand-in named, a message sent in Chat reaches the stand-in and its reply shows.
- A phone and an iPad simulator build still compile, and their behaviour is untouched.

## Later

Menu commands and keyboard shortcuts, window sizes and a Mac sidebar, the iPad's "New window" as a Mac menu item, a
signed build that carries iCloud, widgets on the Mac's desktop, and the share extension.
