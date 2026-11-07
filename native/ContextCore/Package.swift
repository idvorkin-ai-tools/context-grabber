// swift-tools-version: 6.0
import PackageDescription

// The platform-free half of the native app: everything here runs under `swift test` on the Mac (docs/TESTING.md).
let package = Package(
  name: "ContextCore",
  platforms: [.iOS(.v18), .macOS(.v14)],
  products: [
    .library(name: "ContextCore", targets: ["ContextCore"])
  ],
  targets: [
    // Linux only (just test-linux): SQLite from libsqlite3-dev. The Apple SDKs carry it as the SQLite3 module.
    .systemLibrary(name: "CSQLite", providers: [.apt(["libsqlite3-dev"])]),
    .target(name: "ContextCore", dependencies: [.target(name: "CSQLite", condition: .when(platforms: [.linux]))]),
    .testTarget(name: "ContextCoreTests", dependencies: ["ContextCore"], exclude: ["Fixtures"]),
  ],
  swiftLanguageModes: [.v5]
)
