//  The Places launch hooks with a grammar (docs/TESTING.md). Pure; the app's `runImportDatabaseHook` and
//  `runPlacesHook` do the work.

import Foundation

/// `GRABBER_IMPORT_DB=<file>[,recent]`: a path, absolute or under Documents; `recent` shifts the trail by whole days
/// into the last 24 hours.
public struct ImportDatabaseHook: Equatable, Sendable {
  public var file: String
  public var recent: Bool

  public init?(_ env: [String: String]) {
    guard let spec = env["GRABBER_IMPORT_DB"], !spec.isEmpty else { return nil }
    let parts = spec.split(separator: ",").map(String.init)
    guard let file = parts.first else { return nil }  // only commas: no file to import
    self.file = file
    recent = parts.dropFirst().contains("recent")
  }
}

/// `GRABBER_PLACES`: anything opens the screen; `map` first also opens the map full screen; `map,unnamed` then opens
/// the card of the longest unnamed place once the trail is read, and `map,unnamed,name` its naming card (story 056);
/// `open,edit:<name>` opens that known place's screen (story 057).
public struct PlacesHook: Equatable, Sendable {
  public var map: Bool
  public var edit: String?
  public var unnamed: Bool
  public var name: Bool

  public init?(_ env: [String: String]) {
    guard let spec = env["GRABBER_PLACES"], !spec.isEmpty else { return nil }
    let parts = spec.split(separator: ",").map(String.init)
    map = parts.first == "map"
    edit = parts.first(where: { $0.hasPrefix("edit:") }).map { String($0.dropFirst(5)) }
    unnamed = parts.dropFirst().contains("unnamed")
    name = parts.contains("name")
  }
}
