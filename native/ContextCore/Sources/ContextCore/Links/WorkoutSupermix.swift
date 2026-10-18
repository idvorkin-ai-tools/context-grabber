//  Workout Supermix straight in YouTube Music (#372, story 139; spec 2026-10-04-swift-native-app-design.md).

import Foundation

public enum WorkoutSupermix {
  /// Igor's link, as he gave it (2026-10-17): a track YouTube Music runs his workout mix from. A universal link, so
  /// it opens the YouTube Music app, or the browser without it.
  public static let link = URL(string: "https://music.youtube.com/watch?v=SsLFxyVjVqQ")!
}
