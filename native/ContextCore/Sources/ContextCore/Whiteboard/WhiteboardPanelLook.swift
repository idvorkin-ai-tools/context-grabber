//  How the board's open conversation reads (#1384, story 1277; spec 2026-11-12-whiteboard-conversation-design.md,
//  *The conversation as chat*): as lines, or as chat bubbles like Chat's and the Cockpit's web chat.

/// The open conversation's look, switched at its foot and remembered for the next board (Lines when nothing, or
/// something this build doesn't know, is stored).
public enum WhiteboardPanelLook: String, CaseIterable, Sendable {
  case lines, bubbles

  /// The switch's word for it.
  public var title: String {
    switch self {
    case .lines: "Lines"
    case .bubbles: "Bubbles"
    }
  }

  /// One bubble: Igor's on the right, Larry's on the left.
  public struct Bubble: Equatable, Sendable, Identifiable {
    public let id: String
    public let mine: Bool
    public let text: String
    /// A reply of marks with no words: *drew on the board*, said quietly.
    public let quiet: Bool
  }

  /// The panel's thread rows (`WhiteboardNote.recent`) as bubbles: the same messages, never the live rows under them.
  public static func bubbles(_ rows: [WhiteboardNote.Row]) -> [Bubble] {
    rows.compactMap { row in
      switch row.kind {
      case .live: nil
      case .you: Bubble(id: row.id, mine: true, text: row.text, quiet: false)
      case .larry:
        Bubble(id: row.id, mine: false, text: row.text, quiet: row.text == WhiteboardNote.drewOnTheBoard)
      }
    }
  }
}

extension WhiteboardPanelLook {
  /// Where the choice is kept between boards.
  public static let storageKey = "whiteboard_panel_look"
}
