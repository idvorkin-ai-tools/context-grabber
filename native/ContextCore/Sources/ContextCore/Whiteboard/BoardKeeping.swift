//  What the whiteboard store decides about keeping boards on this device (spec 2026-11-01-whiteboard-design.md):
//  where a board's files go, the list read or set aside, a failed save remembered until that board saves (stories 599,
//  612), a new board closed without a stroke dropped (stories 344, 604) and another device's board brought down
//  without losing the last good one (#1043). The app's `WhiteboardStore` and
//  `WhiteboardListView` only carry these out: PencilKit decodes, UIKit draws the picture, CloudKit syncs. The disk is handed in, so a test can give it one that fails.

import Foundation

/// The disk a board's files live on: `FileBoardDisk` in the app, a full or recording one in a test.
public protocol BoardDisk {
  func exists(_ url: URL) -> Bool
  func read(_ url: URL) throws -> Data
  func write(_ data: Data, to url: URL) throws
  func remove(_ url: URL) throws
  func move(_ url: URL, to target: URL) throws
  func makeDirectory(_ url: URL) throws
}

public struct FileBoardDisk: BoardDisk {
  public init() {}
  public func exists(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path) }
  public func read(_ url: URL) throws -> Data { try Data(contentsOf: url) }
  public func write(_ data: Data, to url: URL) throws { try data.write(to: url, options: .atomic) }
  public func remove(_ url: URL) throws { try FileManager.default.removeItem(at: url) }
  public func move(_ url: URL, to target: URL) throws { try FileManager.default.moveItem(at: url, to: target) }
  public func makeDirectory(_ url: URL) throws {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  }
}

/// A disk whose drawings don't fit, as a full one's wouldn't: `GRABBER_WHITEBOARD_SAVE_FAILS=1` on the simulator,
/// whose disk doesn't fill (stories 599, 612). Everything else, the list and the pictures, still goes to `disk`.
public struct FullDisk: BoardDisk {
  let disk: any BoardDisk
  public init(over disk: any BoardDisk) { self.disk = disk }
  public func exists(_ url: URL) -> Bool { disk.exists(url) }
  public func read(_ url: URL) throws -> Data { try disk.read(url) }
  public func write(_ data: Data, to url: URL) throws {
    if url.pathExtension == "drawing" { throw CocoaError(.fileWriteOutOfSpace) }
    try disk.write(data, to: url)
  }
  public func remove(_ url: URL) throws { try disk.remove(url) }
  public func move(_ url: URL, to target: URL) throws { try disk.move(url, to: target) }
  public func makeDirectory(_ url: URL) throws { try disk.makeDirectory(url) }
}

/// A disk whose drawings read as nonsense and can't be moved aside: `GRABBER_WHITEBOARD_UNREADABLE=stuck` on the
/// simulator, so a board reopened after its first save shows what an unreadable board left in place does (#1042).
/// Writes go through, so a new board's first save lands.
public struct StuckUnreadableDisk: BoardDisk {
  let disk: any BoardDisk
  public init(over disk: any BoardDisk) { self.disk = disk }
  public func exists(_ url: URL) -> Bool { disk.exists(url) }
  public func read(_ url: URL) throws -> Data {
    url.pathExtension == "drawing" ? Data("not a drawing".utf8) : try disk.read(url)
  }
  public func write(_ data: Data, to url: URL) throws { try disk.write(data, to: url) }
  public func remove(_ url: URL) throws { try disk.remove(url) }
  public func move(_ url: URL, to target: URL) throws {
    if url.pathExtension == "drawing" { throw CocoaError(.fileWriteNoPermission) }
    try disk.move(url, to: target)
  }
  public func makeDirectory(_ url: URL) throws { try disk.makeDirectory(url) }
}

/// A board's drawing that couldn't be read: why, and where it went. Moved aside, the board starts afresh; left in place
/// because the move failed, the board is held (#1042).
public struct UnreadableDrawing: Error {
  public let board: String
  /// Why it couldn't be read.
  public let reason: any Error
  /// Where it was moved; nil when it couldn't be and stays where it was.
  public let keptAt: URL?
  /// Why it couldn't be moved aside; nil when it was.
  public let stuck: (any Error)?
}

/// A save refused because the board's unreadable drawing couldn't be moved aside: writing would lose it (#1042).
public struct BoardHeld: LocalizedError {
  public let board: String
  public var errorDescription: String? {
    "This board's saved drawing couldn't be read or moved aside, so nothing is saved over it."
  }
}

/// A board brought down from iCloud without its drawing, or its picture: the drawing is asked for again next sync, and
/// a picture is drawn here from the drawing (#1043).
public struct ReplicaIncomplete: LocalizedError {
  public let board: String
  public let asset: String
  public var errorDescription: String? { "iCloud's copy of this board came without its \(asset)." }
}

/// A board's drawing from iCloud that couldn't be read: the one this device had stays, and it's asked for again (#1043).
public struct UnreadableReplica: LocalizedError {
  public let board: String
  public let reason: any Error
  public var errorDescription: String? {
    "iCloud's copy of this board couldn't be read: \(reason.localizedDescription)"
  }
}

/// What a board brought down from iCloud left on this device: its drawing, decoded, and why its picture wasn't kept,
/// if it wasn't (#1043).
public struct ReplicaTaken<Drawing> {
  public let drawing: Drawing
  public let pictureProblem: (any Error)?
}

public struct BoardKeeping {
  /// The whiteboard's folder; nil in a build with nowhere to keep boards, where nothing is read or written.
  public let dir: URL?
  let disk: any BoardDisk
  /// The board the list's problem is about, when it's a save that failed on leaving (story 612).
  public private(set) var unsavedBoard: String?
  /// Boards whose unreadable drawing couldn't be moved aside: no save writes over it until it can be (#1042).
  private var heldBoards: Set<String> = []
  /// The size of each drawing as last read, to check against what its meaning was saved with.
  private var readBytes: [String: Int] = [:]

  public init(dir: URL?, disk: any BoardDisk = FileBoardDisk()) {
    self.dir = dir
    self.disk = disk
  }

  public func drawingURL(_ id: String) -> URL? { dir?.appendingPathComponent("boards/\(id).drawing") }
  public func pictureURL(_ id: String) -> URL? { dir?.appendingPathComponent("boards/\(id).png") }
  /// The board's meaning (`BoardMeaning`), beside its drawing.
  public func meaningURL(_ id: String) -> URL? { dir?.appendingPathComponent("boards/\(id).meaning.json") }
  var indexURL: URL? { dir?.appendingPathComponent("index.json") }

  // MARK: - The list

  /// The list as it was left, or an empty one. One that can't be read is set aside, never saved over: iCloud gives this
  /// device's boards back on the next sync. The error says why, for the list's problem.
  public func readIndex() -> (index: BoardIndex, unreadable: (any Error)?) {
    guard let dir, let indexURL else { return (BoardIndex(), nil) }
    do {
      try disk.makeDirectory(dir.appendingPathComponent("boards"))
      guard disk.exists(indexURL) else { return (BoardIndex(), nil) }
      return (try JSONDecoder().decode(BoardIndex.self, from: disk.read(indexURL)), nil)
    } catch {
      setAside(indexURL)
      return (BoardIndex(), error)
    }
  }

  public func writeIndex(_ index: BoardIndex) throws {
    guard let indexURL else { return }
    try disk.write(JSONEncoder().encode(index), to: indexURL)
  }

  // MARK: - A board's drawing

  /// A board's drawing for its screen: nil when it has none yet. One that can't be read is moved aside, beside any
  /// older one, before the error goes up. If that move fails the file stays where it is and the board is held: no save
  /// writes over it, this launch or the next, until a later open moves it aside (#1042).
  public mutating func drawing<Drawing>(_ id: String, decode: (Data) throws -> Drawing) throws -> Drawing? {
    guard let url = drawingURL(id), disk.exists(url) else {
      heldBoards.remove(id)
      return nil
    }
    do {
      let data = try disk.read(url)
      let drawing = try decode(data)
      heldBoards.remove(id)
      readBytes[id] = data.count
      return drawing
    } catch {
      switch setAside(url) {
      case .success(let aside):
        heldBoards.remove(id)
        throw UnreadableDrawing(board: id, reason: error, keptAt: aside, stuck: nil)
      case .failure(let stuck):
        heldBoards.insert(id)
        throw UnreadableDrawing(board: id, reason: error, keptAt: nil, stuck: stuck)
      }
    }
  }

  /// The size in bytes of the board's drawing as `drawing` last read it; nil when it hasn't, or there was none.
  public func drawingBytes(_ id: String) -> Int? { readBytes[id] }

  /// Whether this board's unreadable drawing is still where it was, so nothing may be saved over it (#1042).
  public func held(_ id: String) -> Bool { heldBoards.contains(id) }

  /// A board drawn on: its drawing written. When the write fails nothing else changes, and a board that closed
  /// unsaved stays so. A held board refuses (#1042). True when this was that board, so the list's problem about it
  /// goes (story 612).
  ///
  /// With `meaning`, the board's meaning is written after the drawing, in the same save (story 1106): a save cut off
  /// between the two leaves the meaning a step behind the ink, never ahead of it, so a batch of Larry's is never
  /// remembered as handled with its ink lost. `meaning` is written as given; the caller sets its `inkBytes`.
  public mutating func save(_ drawing: Data, meaning: BoardMeaning? = nil, board id: String) throws -> Bool {
    guard let url = drawingURL(id) else { throw CocoaError(.fileNoSuchFile) }
    guard !heldBoards.contains(id) else { throw BoardHeld(board: id) }
    try disk.write(drawing, to: url)
    if let meaning { try saveMeaning(meaning, board: id) }
    guard unsavedBoard == id else { return false }
    unsavedBoard = nil
    return true
  }

  /// Another device's board brought down from iCloud: its drawing read and checked before it takes the place of the one
  /// this device had, so a copy that fails, is cut short or can't be read leaves the last good one showing and throws,
  /// for the sync to ask again. The drawing is needed; the picture isn't: one missing or not kept is said, and the
  /// store draws it from the drawing. A held copy of another device's board is only a replica, so a good copy repairs
  /// it and lets it go; a held board of this device's (`mine`) is never replaced (#1042, #1043).
  public mutating func takeReplica<Drawing>(
    _ id: String, mine: Bool, drawing source: URL?, picture pictureSource: URL?, decode: (Data) throws -> Drawing
  ) throws -> ReplicaTaken<Drawing> {
    guard let url = drawingURL(id), let pictureURL = pictureURL(id) else { throw CocoaError(.fileNoSuchFile) }
    guard !(mine && heldBoards.contains(id)) else { throw BoardHeld(board: id) }
    guard let source else { throw ReplicaIncomplete(board: id, asset: "drawing") }
    let data = try disk.read(source)
    let drawing: Drawing
    do {
      drawing = try decode(data)
    } catch {
      throw UnreadableReplica(board: id, reason: error)
    }
    try disk.write(data, to: url)
    heldBoards.remove(id)
    guard let pictureSource else {
      return ReplicaTaken(drawing: drawing, pictureProblem: ReplicaIncomplete(board: id, asset: "picture"))
    }
    do {
      try disk.write(disk.read(pictureSource), to: pictureURL)
      return ReplicaTaken(drawing: drawing, pictureProblem: nil)
    } catch {
      return ReplicaTaken(drawing: drawing, pictureProblem: error)
    }
  }

  /// A board closed with ink that couldn't be saved: the board's screen is gone, so the list says it until that board
  /// next saves (story 612).
  public mutating func closedUnsaved(_ id: String) { unsavedBoard = id }

  /// Closing a board, after its last save: a new board of this device's left without a stroke is gone (stories 344,
  /// 604). One drawn on and cleared, a colour or a name changed, or another device's board, stays.
  public static func dropsOnClose(_ board: BoardEntry?, empty: Bool, device: String) -> Bool {
    guard empty, let board else { return false }
    return board.updated == board.created && BoardIndex.editable(board, on: device)
  }

  /// A deleted board's drawing, picture and meaning, gone from this device; a held board is let go, as asked.
  public mutating func removeFiles(_ id: String) {
    heldBoards.remove(id)
    readBytes[id] = nil
    for url in [drawingURL(id), pictureURL(id), meaningURL(id)].compactMap({ $0 }) { try? disk.remove(url) }
  }

  // MARK: - A board's meaning

  /// The board's meaning as its file holds it; nil when it has none yet. A file that can't be read is set aside,
  /// beside any older one, before the error goes up: the board opens with no meaning rather than none ever saved again.
  public func meaning(_ id: String) throws -> BoardMeaning? {
    guard let url = meaningURL(id), disk.exists(url) else { return nil }
    do {
      return try JSONDecoder().decode(BoardMeaning.self, from: disk.read(url))
    } catch {
      setAside(url)
      throw error
    }
  }

  /// The board's meaning written on its own, when nothing of the ink changed (a fold, a card, a batch refused), or on
  /// a board not drawn on here. A held board's meaning is written too: it is the drawing nothing may overwrite.
  public func saveMeaning(_ meaning: BoardMeaning, board id: String) throws {
    guard let url = meaningURL(id) else { throw CocoaError(.fileNoSuchFile) }
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    try disk.write(encoder.encode(meaning), to: url)
  }

  /// Once per board: the meaning this device kept in UserDefaults (`legacy`) moves into the board's file, which is read
  /// back before the keys go. Never over a file already there, whose keys are let go. Nil when there was nothing to
  /// move; the moved meaning, or why it couldn't be, when there was (the keys then stay, for next launch).
  public func migrateMeaning(_ id: String, from legacy: BoardOpLedger) -> Result<BoardMeaning, any Error>? {
    guard let url = meaningURL(id), let old = legacy.meaning(board: id) else { return nil }
    if disk.exists(url) {
      legacy.forget(board: id)
      return nil
    }
    do {
      try saveMeaning(old, board: id)
      guard try meaning(id) == old else { throw CocoaError(.fileReadCorruptFile) }
      legacy.forget(board: id)
      return .success(old)
    } catch {
      return .failure(error)
    }
  }

  /// A file that can't be read, moved beside it under a name no older one has, so an earlier one set aside stays too.
  @discardableResult
  private func setAside(_ url: URL) -> Result<URL, any Error> {
    var aside = url.appendingPathExtension("unreadable")
    var copy = 2
    while disk.exists(aside) {
      aside = url.appendingPathExtension("\(copy).unreadable")
      copy += 1
    }
    do {
      try disk.move(url, to: aside)
      return .success(aside)
    } catch {
      return .failure(error)
    }
  }
}
