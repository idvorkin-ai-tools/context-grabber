//  The whiteboard's boards (spec 2026-11-01-whiteboard-design.md, stories 347, 348): the list each device keeps, and
//  how iCloud's copy merges into it. A board is drawn only on the device that made it and read everywhere else, so the
//  merge never has two edits of one board to reconcile: the drawing device's copy always wins.

import Foundation

public struct BoardEntry: Codable, Equatable, Identifiable, Sendable {
  public var id: String
  public var title: String
  /// Unix ms.
  public var created: Int64
  /// Unix ms of the last stroke or rename: the list's order, and how iCloud's copy is told to be newer.
  public var updated: Int64
  public var strokes: Int
  /// The install that draws it (the archive's device id) and what that device is ("iPad").
  public var device: String
  public var deviceName: String
  /// This device's own boards: the `updated` iCloud last took; nil until it took one.
  public var uploaded: Int64?

  public init(
    id: String, title: String, created: Int64, updated: Int64, strokes: Int, device: String, deviceName: String,
    uploaded: Int64? = nil
  ) {
    self.id = id
    self.title = title
    self.created = created
    self.updated = updated
    self.strokes = strokes
    self.device = device
    self.deviceName = deviceName
    self.uploaded = uploaded
  }
}

public struct BoardIndex: Codable, Equatable, Sendable {
  public private(set) var boards: [BoardEntry] = []
  /// This device's boards deleted here that iCloud still holds: deleted there on the next sync.
  public private(set) var deleted: [String] = []

  public init(boards: [BoardEntry] = [], deleted: [String] = []) {
    self.boards = boards
    self.deleted = deleted
  }

  /// Newest change first.
  public var sorted: [BoardEntry] { boards.sorted { ($0.updated, $0.id) > ($1.updated, $1.id) } }

  public func board(_ id: String) -> BoardEntry? { boards.first { $0.id == id } }

  /// Only the device that made a board draws on it.
  public static func editable(_ board: BoardEntry, on device: String) -> Bool { board.device == device }

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
    id: String, at date: Date, device: String, deviceName: String, title: String? = nil, timeZone: TimeZone = .current
  ) -> BoardEntry {
    let ms = Int64(date.timeIntervalSince1970 * 1000)
    let entry = BoardEntry(
      id: id, title: title ?? newTitle(at: date, timeZone: timeZone), created: ms, updated: ms, strokes: 0,
      device: device, deviceName: deviceName)
    boards.append(entry)
    return entry
  }

  public mutating func drew(_ id: String, strokes: Int, at ms: Int64) {
    guard let i = boards.firstIndex(where: { $0.id == id }) else { return }
    boards[i].strokes = strokes
    boards[i].updated = max(ms, boards[i].updated)
  }

  public mutating func rename(_ id: String, to title: String, at ms: Int64) {
    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, let i = boards.firstIndex(where: { $0.id == id }) else { return }
    boards[i].title = trimmed
    boards[i].updated = max(ms, boards[i].updated)
  }

  /// Gone from this list; a board iCloud ever took is deleted there on the next sync.
  public mutating func remove(_ id: String) {
    guard let i = boards.firstIndex(where: { $0.id == id }) else { return }
    if boards[i].uploaded != nil, !deleted.contains(id) { deleted.append(id) }
    boards.remove(at: i)
  }

  /// iCloud took this board at `updated`.
  public mutating func uploaded(_ id: String, at updated: Int64) {
    guard let i = boards.firstIndex(where: { $0.id == id }) else { return }
    boards[i].uploaded = updated
  }

  public mutating func deletedInCloud(_ id: String) { deleted.removeAll { $0 == id } }

  /// This device's boards iCloud does not have as they are now.
  public func pendingUploads(device: String) -> [BoardEntry] {
    boards.filter { $0.device == device && $0.uploaded != $0.updated }
  }

  /// iCloud's whole list merged in. Another device's board is taken when it is new here or newer, and dropped when
  /// iCloud no longer has it (its device deleted it); this device's own boards are left as they are, since this
  /// device is where they are drawn. A board deleted here and still in iCloud is not brought back. Returns the ids
  /// whose drawing must be fetched and the ids dropped.
  public mutating func merge(cloud: [BoardEntry], device: String) -> (fetch: [String], dropped: [String]) {
    var fetch: [String] = []
    let cloudIDs = Set(cloud.map(\.id))
    for remote in cloud where remote.device != device && !deleted.contains(remote.id) {
      if let i = boards.firstIndex(where: { $0.id == remote.id }) {
        if remote.updated > boards[i].updated {
          boards[i] = remote
          fetch.append(remote.id)
        }
      } else {
        boards.append(remote)
        fetch.append(remote.id)
      }
    }
    let dropped = boards.filter { $0.device != device && !cloudIDs.contains($0.id) }.map(\.id)
    boards.removeAll { dropped.contains($0.id) }
    return (fetch, dropped)
  }
}
