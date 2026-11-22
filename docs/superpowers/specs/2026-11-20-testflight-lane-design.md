# TestFlight: a lane beside the cable install

Issue [#1012](https://github.com/idvorkin/context-grabber/issues/1012). Igor, 2026-11-20 (O6): "Yes, add the lane
alongside the cable install."

Today a build reaches the phone only over the cable (`just native-run-device`): the phone must be plugged into the
Mac, unlocked and trusted, and the build is a development build. TestFlight lets a build reach the phone (and the
iPad) from anywhere, installed and updated by the TestFlight app, with no cable and no Mac nearby.

## Goals

- One command on the Mac sends the current commit to TestFlight.
- The build carries its commit, as every build does: the session log's first line, a report and What's new name it.
- Each upload gets a build number that is never reused and grows with the history.
- Nothing secret is in the repository: the repository is public, so App Store Connect's key, its ids and where the
  key file lives come from the environment or a local file git ignores.
- When the App Store Connect key is incomplete, the lane says what is missing before it spends a build. A missing
  App Store Connect app record shows only when the upload fails; the lane then keeps the package and points at the
  one-time setup.

## Non-goals

- Replacing the cable install. It stays the everyday path: it is faster, its logs can be pulled, and it is a
  development build.
- External testers, the App Store, review, screenshots or release notes. Igor is the one internal tester.
- Uploading from an agent without Igor's key, or from Linux.
- Automating the one-time setup in App Store Connect.

## What Igor does

- `just testflight` on the Mac, from a clean checkout of the commit to ship. It archives the app in its release
  build with the commit stamped in, signs the app, its widgets and its share extension for App Store distribution,
  and uploads it. It ends by naming the version, the build number and the commit.
- A few minutes later (Apple's processing takes 5–30 minutes) the build appears in the TestFlight app on the phone,
  where Igor installs it.
- `just testflight --export-only` does everything but the upload and says where the signed package is: a check that
  the release build and its distribution signing work, which needs no key.

## What the lane refuses, and says

- **Uncommitted changes**: a TestFlight build must be a commit that exists, so a dirty checkout stops the lane before
  it builds, naming the changed files. (An explicit override exists for an experiment; the build then says it was
  dirty.)
- **No key**: without the key's id, its issuer and the key file, the upload stops before the build starts, saying
  which of the three is missing and where they are read from. `--export-only` needs none of them.
- **A locked Mac or no Xcode account**: the same as the cable build: the lane waits while the Mac is locked and fails
  Xcode's "No Accounts" plainly, and it takes its turn under the Mac's one signing lock.

## The build number

- The marketing version stays as the project says (2.0.0); the build number is the number of commits in the history
  up to the commit being shipped. A later commit on main always has a larger number, and a commit's number is the same
  whoever builds it, so a build number points back to its commit as well as the stamp does.
- Uploading the same commit twice is refused by App Store Connect (the number is taken); that is the right outcome.
  An explicit build number can be given for the rare case that needs one.

## What a TestFlight build gives up

| | Cable install | TestFlight |
|---|---|---|
| Build | development, debug | release, optimized, distribution-signed |
| How it gets to the phone | cable, phone unlocked beside the Mac | the TestFlight app, anywhere |
| Time to the phone | about a minute after the build | the build, the upload, then Apple's processing, 5–30 minutes |
| `just pull-logs` (session logs, reports, crashes from the app's container) | yes | no: a distribution-signed app's container can't be read over the cable |
| Shake reports and crashes reaching the Mac | BugKit's iCloud delivery, development database | BugKit's iCloud delivery, **production** database (below) |
| Code that only exists in a debug build | present | absent (below) |
| Safari's Web Inspector on the Cockpit page | yes | no |

**Reports from a TestFlight build.** A distribution-signed app writes to the production side of the iCloud
container, and the Mac's listener today reads the development side. Until the schema is deployed to production and
the Mac has a reader for production (BugKit's integration guide, "Mac reader and listener"), a TestFlight build's
shake reports and crash reports are kept and sent but do not reach the Mac's inbox. The report dialog, the copyable
errors and the phone's own session log still work on the phone.

**Debug-only code.** As of this change, the app's only debug-only behaviour is the Cockpit page's Web Inspector. The
launch hooks are read from the launch environment, which a TestFlight install never sets, so they are inert there as
they are on a cable install launched from the home screen.

## One-time setup (Igor)

1. App Store Connect → Apps → + New App: iOS, bundle id `com.idvorkin.grabbernative`, any name and SKU. The widgets
   and the share extension need no records of their own; their identifiers already exist from the development
   builds.
2. App Store Connect → Users and Access → Integrations → App Store Connect API → Team Keys: a key with the App Manager
   role (or Admin). Download its `.p8` once and keep it outside the repository.
3. Give the lane the key: three values in the environment, or in the local file git ignores (the testing guide names
   both).
4. TestFlight → Internal Testing: a group with Igor in it, so each processed build is offered to him.
5. Optional, for reports from TestFlight builds to reach the Mac: deploy the BugKit report schema to production and
   set up the production reader, as BugKit's guide says.
6. Before boards can sync from a TestFlight build: deploy the whiteboard's board records to production in the
   CloudKit Console (the container, Schema, *Deploy Schema Changes…*), after a cable build has sent up a board that
   talked with Larry, so the board's thread (#1161) is part of what is deployed. Check first whether the board record
   type is in production at all: if not, no TestFlight build syncs boards today. A board carrying a piece production
   lacks is refused whole, ink included.

## Acceptance criteria

- With the key set up and a clean checkout, `just testflight` uploads a build whose version is 2.0.0, whose build
  number is the commit count, and which, installed from TestFlight, names its commit in the session log's first line.
- Without the key, `just testflight` stops before building and names what is missing; `--export-only` builds and
  signs the package and stops before the upload.
- A dirty checkout stops the lane before building, unless overridden.
- Nothing about the key is in the repository.
- The cable install is unchanged.
