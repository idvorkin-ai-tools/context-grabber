// swift-tools-version: 6.0
import PackageDescription

// ChatWireKit's files, which stay where they are in ContextCore's tree (plan 2026-11-22-contextcore-targets-plan.md).
let chatWireSources = [
  "Chat/ChatWire.swift", "Chat/ChatDecisions.swift", "Chat/ChatMove.swift", "Chat/ChatLinks.swift",
  "Chat/ChatBubbleLinks.swift", "Chat/ChatCockpitLink.swift", "Cockpit/CockpitAddress.swift",
]

// The platform-free half of the native app: everything here runs under `swift test` on the Mac (docs/TESTING.md).
let package = Package(
  name: "ContextCore",
  platforms: [.iOS(.v18), .macOS(.v14)],
  products: [
    .library(name: "ContextCore", targets: ["ContextCore"]),
    // Larry's board changes replayed on a copy of a board and drawn to a PNG, on the Mac (#936; `just board-ops`).
    .executable(name: "board-ops-harness", targets: ["BoardOpsHarness"]),
    // A pulled log's pen touches judged again on the Mac and written as a host fixture (story 1105; `just touch-fixture`).
    .executable(name: "touch-replay", targets: ["TouchReplay"]),
  ],
  targets: [
    // Linux only (just test-linux, and the board-ops harness on Larry's box, #943): the system's SQLite, found through
    // pkg-config's sqlite3 (its headers wherever the system put them); SwiftPM names the package to install when it is
    // missing. The Apple SDKs carry SQLite as the SQLite3 module, so the Mac and iOS never build this.
    .systemLibrary(
      name: "CSQLite", pkgConfig: "sqlite3",
      providers: [.apt(["libsqlite3-dev"]), .brew(["sqlite"]), .yum(["sqlite-devel"])]),
    // The Cockpit chat wire the chat screen and the board share, in place under ContextCore (plan
    // 2026-11-22-contextcore-targets-plan.md); ContextCore excludes the same files and re-exports the module.
    .target(name: "ChatWireKit", path: "Sources/ContextCore", sources: chatWireSources),
    .target(
      name: "ContextCore",
      dependencies: ["ChatWireKit", .target(name: "CSQLite", condition: .when(platforms: [.linux]))],
      exclude: chatWireSources),
    .executableTarget(name: "BoardOpsHarness", dependencies: ["ContextCore"]),
    .executableTarget(name: "TouchReplay", dependencies: ["ContextCore"]),
    .testTarget(name: "ContextCoreTests", dependencies: ["ContextCore"], exclude: ["Fixtures"]),
  ],
  swiftLanguageModes: [.v5]
)
