//  Stories 1103 and 926 (bead context-grabber-h5c0; spec 2026-11-01-whiteboard-shapes-design.md, *Which microphone,
//  and what it hears*): the microphone rows the board offers, in the note's line while the mic is open and under Talk's
//  long press, open or closed, and whether *Find microphones* may read the connected ones now.

import Foundation

public struct BoardMicMenu: Equatable, Sendable {
  /// A microphone the board knows, by its system id and name.
  public struct Microphone: Equatable, Sendable {
    public var id: String
    public var name: String

    public init(id: String, name: String) {
      self.id = id
      self.name = name
    }
  }

  /// One row: *Automatic* (no id) or a microphone, ticked when it is the pick.
  public struct Row: Equatable, Sendable, Identifiable {
    public var pick: String?
    public var name: String
    public var ticked: Bool
    public var id: String { pick ?? "" }

    public init(pick: String?, name: String, ticked: Bool) {
      self.pick = pick
      self.name = name
      self.ticked = ticked
    }
  }

  public var rows: [Row]
  /// *Find microphones* shows: the mic closed and nothing reading, opening or closing it.
  public var canFind: Bool

  /// `savedName` names a pick kept from before a relaunch that no listing since has read: it still shows, ticked.
  public init(microphones: [Microphone], picked: String?, savedName: String, micOpen: Bool, busy: Bool) {
    var rows = [Row(pick: nil, name: "Automatic", ticked: picked == nil)]
    rows += microphones.map { Row(pick: $0.id, name: $0.name, ticked: $0.id == picked) }
    if let picked, !microphones.contains(where: { $0.id == picked }) {
      rows.append(Row(pick: picked, name: savedName, ticked: true))
    }
    self.rows = rows
    canFind = !micOpen && !busy
  }
}
