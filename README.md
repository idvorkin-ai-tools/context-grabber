# Context Grabber

<img src="native/App/Assets.xcassets/AppIcon.appiconset/icon.png" alt="Grabber Native icon" width="128" align="right">

An iOS app that holds up a humane mirror of the week — health, places, a gym timer, box breathing, a call to an AI
coach — and exports it as JSON, so the coach has the context it needs. Why it exists and what it is not:
[docs/jtbd.md](docs/jtbd.md); what it does, journey by journey: [docs/stories/](docs/stories/README.md).

The app is **Grabber Native**, written in Swift and SwiftUI under [`native/`](native/). The original React Native
app was retired and its code removed on 2026-10-17
([design spec](docs/superpowers/specs/2026-10-04-swift-native-app-design.md)).

## What it grabs

- **Health** from HealthKit: steps, heart rate, sleep (with bedtime, wake time and sources), active energy, walking
  distance, weight, HRV, resting heart rate, meditation and exercise minutes — the day and the week
- **Places**: a background location trail kept on the phone, clustered into stays and named places

Grab the week and share the JSON with the iOS share sheet: paste it into Claude, save it to Files, AirDrop it.

## Layout

- `native/ContextCore/` — the platform-free SwiftPM package (the logic, with host tests)
- `native/App/` — the SwiftUI app; `native/Widgets/` — the widgets and Live Activities
- `native/project.yml` — the XcodeGen spec; the `.xcodeproj` is generated, never committed
- `docs/` — the stories, the design specs, [testing](docs/TESTING.md) and [debugging](docs/DEBUGGING.md)

## Setup

```bash
just setup                # swiftlint, xcbeautify, imagemagick, xcodegen from Homebrew
just test                 # the host tests (seconds)
just native-test-sim      # build for the simulator and run the smoke checks
just native-run-device    # build, install and launch on the iPhone (DEVICE=<udid>)
```

Needs Xcode, an Apple ID signed into Xcode, and Developer Mode on the iPhone. With a free Apple ID the app expires
after seven days.

## Related

Part of Igor's [side quests](https://idvork.in/side-quests) — lightweight tech explorations.
