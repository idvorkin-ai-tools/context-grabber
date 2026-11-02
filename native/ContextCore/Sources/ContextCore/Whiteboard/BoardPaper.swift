//  The board's colours (spec 2026-11-01-whiteboard-design.md, story 378): each a pale shade for light mode and a deep
//  one for dark, as ink is black in light mode and white in dark. `BoardPaperTests` holds them to the ink and the ghosts.

import Foundation

public enum BoardPaper: String, CaseIterable, Sendable {
  case plain, cream, sage, lilac, grey

  public var name: String { rawValue.capitalized }

  /// 0xRRGGBB. The light shade is also behind a board's picture on its card, as that ink is always dark.
  public var light: UInt32 {
    switch self {
    case .plain: 0xFFFFFF
    case .cream: 0xFBF3DC
    case .sage: 0xE3EFDD
    case .lilac: 0xECE6F6
    case .grey: 0xE9E9EB
    }
  }

  public var dark: UInt32 {
    switch self {
    case .plain: 0x000000
    case .cream: 0x2B2416
    case .sage: 0x1C2A1E
    case .lilac: 0x251F33
    case .grey: 0x2C2C2E
    }
  }
}
