//  Bead context-grabber-dbku, stories 1206–1208 (spec: native chat, *Between a board and its chat*): a jump between a
//  board and its thread opens the other straight over where Igor is, never through home or a list.

import Foundation

public enum BoardChatJump {
  public enum Target: Hashable, Sendable {
    case board(String)
    case thread(String)

    /// What the session log calls it.
    public var kind: String {
      switch self {
      case .board: return "board"
      case .thread: return "thread"
      }
    }

    public var id: String {
      switch self {
      case .board(let id), .thread(let id): return id
      }
    }
  }

  public enum How: String, Sendable {
    /// Pushed over the screen he is on; *Back* returns to it.
    case slidIn = "slid_in"
    /// It names the screen underneath, the one he jumped from: one step back rather than a second copy.
    case wentBack = "went_back"
    /// A board already open in a window of its own or the whiteboard behind: that one comes forward, as a link brings
    /// it, so one board never has two live copies.
    case broughtForward = "brought_forward"

    /// Whether the way there passes through another screen first: only a board brought forward goes the link's way.
    public var throughList: Bool { self == .broughtForward }
  }

  /// `cameFrom`: what the screen he is on was jumped from, if it was. `openElsewhere`: the target is a board this app
  /// already has open somewhere other than underneath (a thread is never one).
  public static func how(_ target: Target, cameFrom: Target?, openElsewhere: Bool) -> How {
    if target == cameFrom { return .wentBack }
    if case .board = target, openElsewhere { return .broughtForward }
    return .slidIn
  }
}
