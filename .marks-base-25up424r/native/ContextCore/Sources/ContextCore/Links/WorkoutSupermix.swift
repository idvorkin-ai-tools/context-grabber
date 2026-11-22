//  Workout Supermix straight in YouTube Music (#372, story 139; spec 2026-10-04-swift-native-app-design.md), and the
//  other mixes a press and hold on its tile offers (#383, story 221).

import Foundation

public enum WorkoutSupermix {
  /// Igor's link, as he gave it (2026-10-17): a track YouTube Music runs his workout mix from. A universal link, so
  /// it opens the YouTube Music app, or the browser without it.
  public static let link = Mix.workout.link

  /// The menu's mixes, in its order (Igor, 2026-10-18: "I should have likes and Feel Good Supermix").
  public enum Mix: String, CaseIterable, Sendable {
    case workout
    case liked
    case feelGood = "feel_good"

    public var title: String {
      switch self {
      case .workout: return "Workout Supermix"
      case .liked: return "Liked music"
      case .feelGood: return "Feel Good Supermix"
      }
    }

    /// The menu's icon (Igor, 2026-10-18): Apple's symbols until the drawn art of the press-and-hold popovers.
    /// ponytail: SF Symbols has no kettlebell with headphones, so Workout wears headphones alone; the drawn
    /// popover art (tile style, Igor's pick) replaces all three.
    public var symbol: String {
      switch self {
      case .workout: return "headphones"
      case .liked: return "heart.fill"
      case .feelGood: return "sun.max.fill"
      }
    }

    public var link: URL {
      switch self {
      case .workout: return URL(string: "https://music.youtube.com/watch?v=SsLFxyVjVqQ")!
      // YouTube Music's own list of the account's likes.
      case .liked: return URL(string: "https://music.youtube.com/playlist?list=LM")!
      // Igor's link from #383, without the &feature=share.
      case .feelGood:
        return URL(string: "https://music.youtube.com/playlist?list=RDTMAK5uy_nuKPeaybq-IRcrMnaR-5TIfvKxB7fVJu0")!
      }
    }
  }
}
