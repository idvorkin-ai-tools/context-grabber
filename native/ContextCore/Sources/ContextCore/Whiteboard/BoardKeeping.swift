//  What the whiteboard store decides about keeping boards on this device (spec 2026-11-01-whiteboard-design.md):
//  where a board's files go, the list read or set aside, a failed save remembered until that board saves (stories 599,
//  612), a new board closed without a stroke dropped (stories 344, 604), the *New boards on paper* switch (590, 602),
//  and the trial on paper's read-only copy, offered only on this device's boards (435–439, 601). The app's
//  `WhiteboardStore` and `WhiteboardListView` only carry these out: PencilKit decodes, UIKit draws the picture,
//  CloudKit syncs. The disk is handed in, so a test can give it one that fails.

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

public struct BoardKeeping {
  /// The whiteboard's folder; nil in a build with nowhere to keep boards, where nothing is read or written.
  public let dir: URL?
  let disk: any BoardDisk
  /// The board the list's problem is about, when it's a save that failed on leaving (story 612).
  public private(set) var unsavedBoard: String?

  public init(dir: URL?, disk: any BoardDisk = FileBoardDisk()) {
    self.dir = dir
    self.disk = disk
  }

  public func drawingURL(_ id: String) -> URL? { dir?.appendingPathComponent("boards/\(id).drawing") }
  public func pictureURL(_ id: String) -> URL? { dir?.appendingPathComponent("boards/\(id).png") }
  var indexURL: URL? { dir?.appendingPathComponent("index.json") }

  // MARK: - The switch (stories 590, 595, 602, 607, 651)

  /// The store's key for *New boards on paper*.
  public static let newBoardsOnPaperKey = "whiteboard_new_boards_on_paper"

  public enum SwitchHook: Equatable {
    case set(Bool)
    case forget
  }

  /// What `GRABBER_WHITEBOARD_NEW_ON_PAPER` asks of the stored switch, for the simulator: `on` or `off` (anything but
  /// `on` is off) as if it had been set, `untouched` as if it never was; no hook leaves it be.
  public static func switchHook(_ hook: String?) -> SwitchHook? {
    guard let hook else { return nil }
    return hook == "untouched" ? .forget : .set(hook == "on")
  }

  /// On until it's turned off. It only decides what **+** makes: a board keeps what it was made as.
  public static func newBoardsOnPaper(stored: Bool?) -> Bool { stored ?? true }

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

  /// A board's drawing for its screen: nil when it has none yet. One that can't be read is moved aside before the
  /// error goes up. If that move fails, the file stays in place and the next save writes over it, which the spec's
  /// "The board is kept" does not allow yet.
  public func drawing<Drawing>(_ id: String, decode: (Data) throws -> Drawing) throws -> Drawing? {
    guard let url = drawingURL(id), disk.exists(url) else { return nil }
    do {
      return try decode(disk.read(url))
    } catch {
      setAside(url)
      throw error
    }
  }

  /// A board drawn on: its drawing written. When the write fails nothing else changes, and a board that closed
  /// unsaved stays so. True when this was that board, so the list's problem about it goes (story 612).
  public mutating func save(_ drawing: Data, board id: String) throws -> Bool {
    guard let url = drawingURL(id) else { throw CocoaError(.fileNoSuchFile) }
    try disk.write(drawing, to: url)
    guard unsavedBoard == id else { return false }
    unsavedBoard = nil
    return true
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

  /// A deleted board's drawing and picture, gone from this device.
  public func removeFiles(_ id: String) {
    for url in [drawingURL(id), pictureURL(id)].compactMap({ $0 }) { try? disk.remove(url) }
  }

  // MARK: - The trial on paper (TEMPORARY, as the trial is)

  /// *Try on paper* is offered on this device's boards, on paper or not (stories 435, 601), never another device's.
  public static func offersTrial(_ board: BoardEntry, on device: String) -> Bool {
    BoardIndex.editable(board, on: device)
  }

  /// The board's ink for the trial's copy, read and nothing else: unlike `drawing(_:decode:)`, a file that can't be
  /// read stays where it is, and nothing is written, moved or removed. Nil when the board has no ink yet.
  public func trialInk<Drawing>(_ id: String, decode: (Data) throws -> Drawing) throws -> Drawing? {
    guard let url = drawingURL(id), disk.exists(url) else { return nil }
    return try decode(disk.read(url))
  }

  private func setAside(_ url: URL) {
    let aside = url.appendingPathExtension("unreadable")
    try? disk.remove(aside)
    try? disk.move(url, to: aside)
  }
}
