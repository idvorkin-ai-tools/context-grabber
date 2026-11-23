//  Which build sent a post (story 1134, bead context-grabber-esw3): every message the app sends the Cockpit carries the
//  build number (CFBundleVersion) and the short commit (the GitSha stamp the build recipes put in Info.plist), under
//  the same two names, so Larry can answer "am I running it?" from the message alone. In ChatWireKit, the module the
//  chat's and the board's posts are both built on.

import Foundation

public struct AppBuild: Equatable, Sendable {
  /// CFBundleVersion, like "212".
  public var build: String
  /// The short git sha the build was made from; "dev" from Xcode's Run button.
  public var sha: String

  public init(build: String, sha: String) {
    self.build = build
    self.sha = sha
  }

  /// The two names on the wire, the same on every post.
  public static let buildKey = "app_build"
  public static let shaKey = "app_sha"

  /// Nothing to say: a post goes without either name.
  public static let none = AppBuild(build: "", sha: "")

  /// This app's or extension's own Info.plist. Only a bundle carrying the GitSha stamp is ours: the test runner's
  /// bundle has a CFBundleVersion of its own, and it says nothing about the app.
  public static let current = AppBuild(info: Bundle.main.infoDictionary ?? [:])

  public init(info: [String: Any]) {
    let value = { (key: String) in (info[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }
    let sha = value("GitSha")
    self.init(build: sha.isEmpty ? "" : value("CFBundleVersion"), sha: sha)
  }

  /// The fields a post's body takes; an empty value is left out rather than sent empty.
  public var wire: [String: String] {
    var out: [String: String] = [:]
    if !build.isEmpty { out[Self.buildKey] = build }
    if !sha.isEmpty { out[Self.shaKey] = sha }
    return out
  }

  /// A post's body with the build added; a field the body already has is kept.
  public func stamp(_ body: [String: Any]) -> [String: Any] {
    body.merging(wire) { mine, _ in mine }
  }
}
