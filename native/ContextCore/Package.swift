// swift-tools-version: 6.0
import PackageDescription

// The platform-free half of the native app: everything here runs under `swift test` on the Mac (docs/TESTING.md).
let package = Package(
  name: "ContextCore",
  platforms: [.iOS(.v18), .macOS(.v14)],
  products: [
    .library(name: "ContextCore", targets: ["ContextCore"]),
    // Larry's board changes replayed on a copy of a board and drawn to a PNG, on the Mac (#936; `just board-ops`).
    .executable(name: "board-ops-harness", targets: ["BoardOpsHarness"]),
  ],
  targets: [
    // Linux only (just test-linux, and the board-ops harness on Larry's box, #943): the system's SQLite, found through
    // pkg-config's sqlite3 (its headers wherever the system put them); SwiftPM names the package to install when it is
    // missing. The Apple SDKs carry SQLite as the SQLite3 module, so the Mac and iOS never build this.
    .systemLibrary(
      name: "CSQLite", pkgConfig: "sqlite3",
      providers: [.apt(["libsqlite3-dev"]), .brew(["sqlite"]), .yum(["sqlite-devel"])]),
    .target(name: "ContextCore", dependencies: [.target(name: "CSQLite", condition: .when(platforms: [.linux]))]),
    .executableTarget(name: "BoardOpsHarness", dependencies: ["ContextCore"]),
    .testTarget(name: "ContextCoreTests", dependencies: ["ContextCore"], exclude: ["Fixtures"]),
  ],
  swiftLanguageModes: [.v5]
)
