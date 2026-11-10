//  The Places launch hooks (docs/TESTING.md); `ImportDatabaseHook` and `PlacesHook` in ContextCore read them. The
//  import runs first, so the other hooks see the imported trail.

import ContextCore
import Foundation

extension AppModel {
  /// "<file>[,recent]": a path, absolute or under Documents; "recent" shifts it by whole days into the last 24 hours.
  func runImportDatabaseHook(_ hook: ImportDatabaseHook) {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let url = hook.file.hasPrefix("/") ? URL(fileURLWithPath: hook.file) : docs.appendingPathComponent(hook.file)
    places.importDatabase(url, from: "hook", recent: hook.recent)
  }

  /// "open" opens the screen; "map" also opens the map full screen; "map,unnamed" then opens the card of the
  /// longest unnamed place once the trail is read, and "map,unnamed,name" its naming card (story 056).
  func runPlacesHook(_ hook: PlacesHook) {
    openPlaces(from: "hook")
    if hook.map { showPlacesMap = true }
    // "open,edit:<name>" opens that known place's screen, for a screenshot of its icon picker (story 057).
    if let name = hook.edit {
      if let place = places.knownPlaces.first(where: { $0.name == name }) { places.edit(place, from: "hook") }
    }
    if hook.unnamed {
      Task {
        for _ in 0..<100 where places.loading || places.unnamed.isEmpty {
          try? await Task.sleep(for: .milliseconds(200))
        }
        guard let place = places.unnamed.first else { return }
        places.selectUnnamed(place.placeId, from: "hook")
        if hook.name { places.startNaming(place) }
      }
    }
  }

  /// Prepares the file as Export database does, without the share sheet a script cannot dismiss.
  func runExportHook() {
    places.prepareExport(from: "hook")
    places.exportFile = nil
  }
}
