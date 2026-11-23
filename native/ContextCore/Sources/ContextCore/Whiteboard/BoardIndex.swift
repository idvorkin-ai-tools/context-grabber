//  The whiteboard's boards (spec 2026-11-01-whiteboard-design.md, stories 347, 348): the list each device keeps, and
//  how iCloud's copy merges into it. A board is drawn only on the device that made it and read everywhere else, so the
//  merge never has two edits of one board to reconcile: the drawing device's copy always wins.

import Foundation

public struct BoardEntry: Codable, Equatable, Identifiable, Sendable {
  public var id: String
  public var title: String
  /// Unix ms.
  public var created: Int64
  /// Unix ms of the last stroke, rename or colour: the list's order, and how iCloud's copy is told to be newer.
  public var updated: Int64
  public var strokes: Int
  /// The install that draws it (the archive's device id) and what that device is ("iPad").
  public var device: String
  public var deviceName: String
  /// This device's own boards: the `updated` iCloud last took; nil until it took one.
  public var uploaded: Int64?
  /// The `updated` whose drawing this device holds: always current for a board drawn here, the last that arrived
  /// for another device's; nil until one did.
  public var fetched: Int64?
  /// The board's colour by name; nil, or a name from a newer build, shows as Plain and is kept as it is.
  public var paperID: String?
  /// Made as a board on paper (stories 590, 591, 593). Set once when it's made; nil is every board from before.
  public var onPages: Bool?
  /// The board's chat thread with Larry as iCloud carries it (#1161, story 769): on the drawing device, the one iCloud
  /// last took; on any other, the one iCloud brought. nil for a board that never talked with Larry, or one last sent
  /// up before boards carried their thread.
  public var thread: String?

  public var paper: BoardPaper { paperID.flatMap(BoardPaper.init(rawValue:)) ?? .plain }

  /// This device holds the drawing of the version it knows of.
  public var current: Bool { fetched == updated }

  /// Some version's drawing is on this device: a board made here, or one whose first download landed. Until then it
  /// has nothing to open but a blank (bead context-grabber-1jb4).
  public var arrived: Bool { fetched != nil }

  public init(
    id: String, title: String, created: Int64, updated: Int64, strokes: Int, device: String, deviceName: String,
    uploaded: Int64? = nil, fetched: Int64? = nil, paperID: String? = nil, onPages: Bool? = nil, thread: String? = nil
  ) {
    self.id = id
    self.title = title
    self.created = created
    self.updated = updated
    self.strokes = strokes
    self.device = device
    self.deviceName = deviceName
    self.uploaded = uploaded
    self.fetched = fetched
    self.paperID = paperID
    self.onPages = onPages
    self.thread = thread
  }
}

public struct BoardIndex: Codable, Equatable, Sendable {
  public private(set) var boards: [BoardEntry] = []
  /// Boards deleted here that iCloud still holds: deleted there on the next sync.
  public private(set) var deleted: [String] = []
  /// The `updated` each of `deleted` had when it was deleted here: the delete covers that version and older.
  public private(set) var deletedVersions: [String: Int64] = [:]

  public init(boards: [BoardEntry] = [], deleted: [String] = []) {
    self.boards = boards
    self.deleted = deleted
  }

  /// A list saved before `deletedVersions` existed still reads.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    boards = try container.decode([BoardEntry].self, forKey: .boards)
    deleted = try container.decode([String].self, forKey: .deleted)
    deletedVersions = try container.decodeIfPresent([String: Int64].self, forKey: .deletedVersions) ?? [:]
  }

  /// Newest change first.
  public var sorted: [BoardEntry] { boards.sorted { ($0.updated, $0.id) > ($1.updated, $1.id) } }

  /// The list's rows, newest first: a board waits out of it until its first drawing has come down, so a failed first
  /// download never opens blank, nor gets drawn over blank on the device that made it (bead context-grabber-1jb4).
  public var shown: [BoardEntry] { sorted.filter(\.arrived) }

  public func board(_ id: String) -> BoardEntry? { boards.first { $0.id == id } }

  /// Only the device that made a board draws on it.
  public static func editable(_ board: BoardEntry, on device: String) -> Bool { board.device == device }

  /// Every board opens on paper (Igor, 2026-11-07: the old canvas is gone). Only a board made on paper, on the device
  /// that made it, can be drawn on; the rest are look-only. Nothing is drawn on a phone, its own boards included
  /// (story 746; Igor, 2026-11-10: "we can't do hand drawing").
  public static func drawable(_ board: BoardEntry, on device: String, onPhone: Bool = false) -> Bool {
    !onPhone && board.onPages == true && editable(board, on: device)
  }

  /// A phone only looks at boards, so it starts none (story 746).
  public static func startsBoards(onPhone: Bool) -> Bool { !onPhone }

  /// Drawn on the canvas that's gone: its ink sits where that canvas put it, so it's moved onto pages to be shown, and
  /// it's look-only even on the device that made it.
  public static func drawnOnTheOldCanvas(_ board: BoardEntry) -> Bool { board.onPages != true }

  /// Story 1200: whether the board has *Send to Larry*. Every board but one drawn on the old canvas, wherever it opens:
  /// that one's ink is moved onto pages to be shown, not where it's saved, so there is no frame to show Larry.
  public static func sendable(_ board: BoardEntry) -> Bool { !drawnOnTheOldCanvas(board) }

  /// What the bar says on a board that can't be drawn on here; nil on one that can.
  public static func lookOnlyNote(_ board: BoardEntry, on device: String, onPhone: Bool = false) -> String? {
    if onPhone { return "Look only on iPhone: draw on the iPad" }
    if drawable(board, on: device) { return nil }
    if !editable(board, on: device) { return "Drawn on \(board.deviceName): look only" }
    return "Drawn on the old canvas: look only"
  }

  /// Why the board can't be opened as it is now (#603): not on this device, or its latest drawing not down from iCloud
  /// yet; nil when it can. Asked once iCloud has been. `iCloud`: false in a build that can't reach it (the Mac's own,
  /// #1254), where another device's board never comes.
  public func whyNotOpen(_ id: String, iCloud: Bool = true) -> String? {
    guard let board = board(id) else {
      return iCloud
        ? "This board isn't on this device: it was deleted, or iCloud hasn't brought it here."
        : "This board isn't on this device, and this build can't reach iCloud to bring it here: open it on the device"
          + " that drew it."
    }
    return board.current
      ? nil : "This board's latest drawing hasn't come down from iCloud, so it can't be opened as it is now."
  }

  /// A new board's name: *Board, Nov 1*, then *Board, Nov 1 (2)* for the day's second.
  public func newTitle(at date: Date, timeZone: TimeZone = .current) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = timeZone
    f.dateFormat = "MMM d"
    let base = "Board, " + f.string(from: date)
    let taken = Set(boards.map(\.title))
    guard taken.contains(base) else { return base }
    var n = 2
    while taken.contains("\(base) (\(n))") { n += 1 }
    return "\(base) (\(n))"
  }

  @discardableResult
  public mutating func add(
    id: String, at date: Date, device: String, deviceName: String, title: String? = nil, timeZone: TimeZone = .current,
    onPages: Bool = false
  ) -> BoardEntry {
    let ms = Int64(date.timeIntervalSince1970 * 1000)
    let entry = BoardEntry(
      id: id, title: title ?? newTitle(at: date, timeZone: timeZone), created: ms, updated: ms, strokes: 0,
      device: device, deviceName: deviceName, fetched: ms, onPages: onPages ? true : nil)
    boards.append(entry)
    return entry
  }

  public mutating func drew(_ id: String, strokes: Int, at ms: Int64) {
    guard let i = boards.firstIndex(where: { $0.id == id }) else { return }
    boards[i].strokes = strokes
    boards[i].updated = max(ms, boards[i].updated)
    boards[i].fetched = boards[i].updated
  }

  public mutating func rename(_ id: String, to title: String, at ms: Int64) {
    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, let i = boards.firstIndex(where: { $0.id == id }) else { return }
    let current = boards[i].fetched == boards[i].updated
    boards[i].title = trimmed
    boards[i].updated = max(ms, boards[i].updated)
    if current { boards[i].fetched = boards[i].updated }
  }

  /// A colour for the board. One not yet changed stays new, so closing it without a stroke still takes it away (its
  /// first stroke takes the colour up); any other is a change iCloud has to take.
  public mutating func setPaper(_ id: String, to paper: BoardPaper, at ms: Int64) {
    guard let i = boards.firstIndex(where: { $0.id == id }), boards[i].paper != paper else { return }
    boards[i].paperID = paper.rawValue
    guard boards[i].updated != boards[i].created else { return }
    let current = boards[i].fetched == boards[i].updated
    boards[i].updated = max(ms, boards[i].updated)
    if current { boards[i].fetched = boards[i].updated }
  }

  /// Gone from this list; a board iCloud took, or may be taking (it was ever changed, or another device drew it), is
  /// deleted there on the next sync.
  public mutating func remove(_ id: String, device: String) {
    guard let i = boards.firstIndex(where: { $0.id == id }) else { return }
    let mayBeInICloud =
      boards[i].device != device || boards[i].uploaded != nil || boards[i].updated != boards[i].created
    if mayBeInICloud, !deleted.contains(id) {
      deleted.append(id)
      deletedVersions[id] = boards[i].updated
    }
    boards.remove(at: i)
  }

  /// iCloud took this board at `updated`, carrying `thread` (#1161), or none: what `thread(sending:)` gave.
  public mutating func uploaded(_ id: String, at updated: Int64, thread: String? = nil) {
    guard let i = boards.firstIndex(where: { $0.id == id }) else { return }
    boards[i].uploaded = updated
    boards[i].thread = thread
  }

  /// The thread this device sends up with its own `board` (#1161): its own (`threads`), else none when the one the
  /// board carries is one the Cockpit said is gone (`gone`, context-grabber-e3vb), else the one the board carries. So
  /// a reinstall, which knows no threads of its own yet, never clears one.
  public static func thread(
    sending board: BoardEntry, threads: [String: String], gone: [String: String] = [:]
  ) -> String? {
    if let mine = threads[board.id] { return mine }
    if let carried = board.thread, gone[board.id] == carried { return nil }
    return board.thread
  }

  public mutating func deletedInCloud(_ id: String) {
    deleted.removeAll { $0 == id }
    deletedVersions[id] = nil
  }

  /// This device now holds the drawing of version `updated`.
  public mutating func fetched(_ id: String, at updated: Int64) {
    guard let i = boards.firstIndex(where: { $0.id == id }) else { return }
    boards[i].fetched = updated
  }

  /// This device's boards iCloud does not have as they are now: a change iCloud hasn't taken, or a chat thread with
  /// Larry (`threads`, board id to thread, this device's) iCloud doesn't carry yet (#1161), so a board that talked
  /// with Larry, even one from before boards carried their thread, goes up without new ink. A thread the Cockpit said
  /// is gone (`gone`) that the board still carries sends it up too, to clear it (context-grabber-e3vb).
  public func pendingUploads(device: String, threads: [String: String] = [:], gone: [String: String] = [:])
    -> [BoardEntry]
  {
    boards.filter { board in
      board.device == device
        && (board.uploaded != board.updated
          || Self.thread(sending: board, threads: threads, gone: gone) != board.thread)
    }
  }

  /// The iCloud record that says a board was deleted (#613). The device that drew a board keeps it through an empty
  /// iCloud list, so a delete asked for on another device reaches it only by being said out loud. Old builds can't
  /// read one and pass over it. ponytail: never cleared, as the drawing device may be off for good; a few bytes each,
  /// and a board's id is never used again.
  public static func tombstone(of id: String) -> String { tombstonePrefix + id }

  /// The board a record of iCloud's says was deleted; nil for a board's own record.
  public static func tombstoned(by record: String) -> String? {
    record.hasPrefix(tombstonePrefix) ? String(record.dropFirst(tombstonePrefix.count)) : nil
  }

  private static let tombstonePrefix = "deleted-"

  /// iCloud's whole list merged in. Another device's board is taken when it is new here or newer, and dropped when
  /// iCloud no longer has it (a device deleted it). This device's own boards are left as they are, since this
  /// device is where they are drawn, except one iCloud has that this list lost (a reinstall, an unreadable list),
  /// which comes back. A board deleted here and still in iCloud is not brought back. `unread`: records iCloud holds
  /// that could not be read, never dropped for it. `tombstones`: boards some device deleted, with the `updated` it
  /// saw, which go from here too, unless this device drew one and has a change iCloud lacks or has it open (`open`).
  /// A board changed after that version outlives the tombstone, and this device sends it again, since the delete took
  /// its record. Returns the ids whose drawing must be fetched (until a fetch lands, every merge asks again), the ids
  /// dropped, and whether any board now needs sending again.
  public mutating func merge(
    cloud: [BoardEntry], device: String, unread: Set<String> = [], tombstones: [String: Int64] = [:],
    open: Set<String> = []
  ) -> (fetch: [String], dropped: [String], resend: Bool) {
    func covered(_ board: BoardEntry) -> Bool { tombstones[board.id].map { board.updated <= $0 } ?? false }
    let cloudIDs = Set(cloud.map(\.id)).union(unread)
    for remote in cloud where !deleted.contains(remote.id) && !covered(remote) {
      if let i = boards.firstIndex(where: { $0.id == remote.id }) {
        if remote.device != device, remote.updated > boards[i].updated {
          var taken = remote
          taken.fetched = boards[i].fetched
          boards[i] = taken
        } else if remote.device != device {
          // #1161: the drawing device sends a thread up without new ink; it needs no drawing fetched. None at the same
          // `updated` is a thread it cleared because the Cockpit lost it (context-grabber-e3vb).
          boards[i].thread = remote.thread
        }
      } else {
        var taken = remote
        if remote.device == device { taken.uploaded = remote.updated }
        boards.append(taken)
      }
    }
    let dropped = boards.filter { board in
      if board.device != device { return !cloudIDs.contains(board.id) || covered(board) }
      return covered(board) && board.uploaded == board.updated && !open.contains(board.id)
    }.map(\.id)
    boards.removeAll { dropped.contains($0.id) }
    var resend = false
    for i in boards.indices
    where boards[i].device == device && tombstones[boards[i].id] != nil && !covered(boards[i])
      && boards[i].uploaded == boards[i].updated
    {
      boards[i].uploaded = nil
      resend = true
    }
    let fetch = boards.filter { cloudIDs.contains($0.id) && !unread.contains($0.id) && $0.fetched != $0.updated }
      .map(\.id)
    return (fetch, dropped, resend)
  }
}
