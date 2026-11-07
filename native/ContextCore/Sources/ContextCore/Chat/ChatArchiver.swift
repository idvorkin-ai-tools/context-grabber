//  Archiving a chat (#589, #599; stories 307–309, 311–314): a row moves at once on screen, then on the Cockpit. A
//  refusal puts it back and says why; a swipe's or a batch's archive is offered back for five seconds; one change at a
//  time per thread, so an Undo while the archive is unanswered waits for that answer; and a list read that started
//  before a change is stale, since it would put the thread back where it was. The chat's model holds the list, the
//  offer and the problem for the screen; it hands in the transport and the sleep, so a host test can step both.

import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// What the archive reads and changes on the chat's model.
@MainActor
public protocol ChatArchiveList: AnyObject {
  /// The list as the screen shows it.
  var threads: [ChatSummary] { get set }
  /// The last archive from the list, offered back.
  var undoArchive: [ChatSummary] { get set }
  /// Why the last archive or unarchive didn't take.
  var archiveProblem: String? { get set }
  /// One change answered, for the session log.
  func archiveLogged(_ event: ChatArchiver.Event)
  /// An unarchive the Cockpit took: the Cockpit may still call it done (an old thread), so its list settles where the
  /// row belongs.
  func archiveUnarchived() async
}

/// A row's archive action: what its swipe or its thread's ⋯ menu offers.
public enum ChatArchiveAction: Equatable, Sendable {
  case archive, unarchive

  /// A swipe left archives a live thread, or brings back an archived one; a pinned or Done thread has none.
  public static func swipe(_ thread: ChatSummary) -> ChatArchiveAction? {
    if thread.archived { return .unarchive }
    return !thread.done && !thread.pinned ? .archive : nil
  }

  /// The thread's ⋯ menu: none on the pinned thread (#598), otherwise the way it isn't.
  public static func menu(_ thread: ChatSummary) -> ChatArchiveAction? {
    thread.pinned ? nil : thread.archived ? .unarchive : .archive
  }
}

@MainActor
public final class ChatArchiver {
  /// `POST` the request; the answer's body and HTTP status (nil when it wasn't HTTP).
  public typealias Transport = @MainActor (URLRequest) async throws -> (Data, Int?)
  /// Waits that long, or returns early once cancelled.
  public typealias Sleep = @MainActor (Duration) async -> Void

  /// How long a swipe's or a batch's archive is offered back (#589).
  public static let undoLife: Duration = .seconds(5)

  public struct Event: Equatable, Sendable {
    public let archive: Bool
    public let thread: String
    public let from: String
    /// Why it didn't take; nil when it did.
    public let failure: String?

    public var fields: [String: any Sendable] {
      [
        "action": archive ? "archive" : "unarchive", "thread": thread, "from": from, "ok": failure == nil,
        "reason": failure ?? "",
      ]
    }
  }

  public typealias Failure = (title: String, reason: String)

  /// Bumped by each archive change and its answer: a list read that started before one is stale.
  public private(set) var epoch = 0
  /// The archive change on its way for a thread, shown over any list that comes back meanwhile.
  private var archiving: [String: Bool] = [:]
  /// Each thread's latest archive change: the next one waits for its answer.
  private var changes: [String: Task<Failure?, Never>] = [:]
  private var undoTask: Task<Void, Never>?
  private var undoOffer = 0

  private weak var list: (any ChatArchiveList)?
  private let cockpit: String
  private let transport: Transport
  private let sleep: Sleep

  public init(
    list: any ChatArchiveList, cockpit: String, transport: @escaping Transport,
    sleep: @escaping Sleep = { try? await Task.sleep(for: $0) }
  ) {
    self.list = list
    self.cockpit = cockpit
    self.transport = transport
    self.sleep = sleep
  }

  // MARK: The list's reads

  /// A list read that started at `epoch` can be shown: no archive change started or was answered since.
  public func isCurrent(_ epoch: Int) -> Bool { epoch == self.epoch }

  /// The Cockpit's rows with this phone's unanswered archive changes over them.
  public func overlaid(_ rows: [ChatSummary]) -> [ChatSummary] {
    rows.map { row in archiving[row.key].map(row.archiving) ?? row }
  }

  // MARK: Changes

  /// One thread: a swipe, the ⋯ menu or an Undo.
  public func setArchived(_ key: String, _ archive: Bool, from: String) async {
    await setArchived([key], archive, from: from)
  }

  /// Several threads together (#599): one problem names every thread that didn't take.
  public func setArchived(_ keys: [String], _ archive: Bool, from: String) async {
    let queued = keys.map { key in
      if !archive { list?.undoArchive.removeAll { $0.key == key } }
      let earlier = changes[key]
      let change = Task { [weak self] () -> Failure? in
        _ = await earlier?.value
        return await self?.apply(key, archive, from: from)
      }
      changes[key] = change
      return change
    }
    var failed: [Failure] = []
    for change in queued {
      guard let failure = await change.value else { continue }
      failed.append(failure)
      list?.archiveProblem = ChatWire.archiveProblem(failed, archive: archive)
    }
  }

  /// The ticked threads, together (#599). The undo offer covers only this batch.
  public func archiveSelected(_ keys: [String]) async {
    list?.undoArchive = []
    await setArchived(keys, true, from: "select")
  }

  /// Archives or brings back `key` at once on screen, then on the Cockpit; a refusal puts the row back and is returned.
  private func apply(_ key: String, _ archive: Bool, from: String) async -> Failure? {
    guard let list, let index = list.threads.firstIndex(where: { $0.key == key }),
      list.threads[index].archived != archive
    else { return nil }
    let before = list.threads[index]
    list.threads[index] = before.archiving(archive)
    epoch += 1
    archiving[key] = archive
    list.archiveProblem = nil
    if archive, from == "swipe" || from == "select" { offerUndo(before, from: from) }
    var failure: String?
    do {
      let (body, status) = try await transport(try ChatWire.archiveRequest(key, archive: archive, cockpit: cockpit))
      failure = ChatWire.archiveFailure(status: status, body: body)
    } catch {
      failure = ChatWire.archiveFailure(status: nil, body: nil, error: error.localizedDescription)
    }
    archiving[key] = nil
    epoch += 1
    list.archiveLogged(Event(archive: archive, thread: key, from: from, failure: failure))
    guard let failure else {
      if !archive { await list.archiveUnarchived() }
      return nil
    }
    if let now = list.threads.firstIndex(where: { $0.key == key }) { list.threads[now] = before }
    list.undoArchive.removeAll { $0.key == key }
    return (before.title, failure)
  }

  /// A swipe's offer replaces the last; a batch's grows. Either way the five seconds start again.
  private func offerUndo(_ before: ChatSummary, from: String) {
    guard let list else { return }
    list.undoArchive = from == "swipe" ? [before] : list.undoArchive + [before]
    undoOffer += 1
    let offer = undoOffer
    let sleep = sleep
    undoTask?.cancel()
    undoTask = Task { [weak self] in
      await sleep(Self.undoLife)
      guard !Task.isCancelled, let self, self.undoOffer == offer else { return }
      self.list?.undoArchive = []
    }
  }

  // MARK: What the list says

  /// The line over the list while an archive is offered back.
  public static func undoLine(_ undo: [ChatSummary]) -> String? {
    guard let first = undo.first else { return nil }
    return undo.count == 1 ? "Archived \"\(first.title)\"" : "Archived \(undo.count) chats"
  }
}

extension ChatSummary {
  /// The row's *Looks done* mark: Larry's proposal, until the thread is Done.
  public var showsLooksDone: Bool { looksDone && !done }
}

/// Select and Review on the chat list (#599, stories 311–314): which rows tick, what *Archive (N)* takes, and which
/// parts of the list show meanwhile.
public struct ChatListSelection: Equatable, Sendable {
  /// *Select* is on: live rows tick instead of opening.
  public private(set) var selecting = false
  public private(set) var picked: Set<String> = []

  public init() {}

  public static func live(_ threads: [ChatSummary]) -> [ChatSummary] { threads.filter { !$0.done } }
  public static func done(_ threads: [ChatSummary]) -> [ChatSummary] { threads.filter(\.done) }
  /// Live threads Larry judges finished: what Review ticks.
  public static func looksDone(_ threads: [ChatSummary]) -> [ChatSummary] { live(threads).filter(\.looksDone) }

  /// The Review line, while not selecting and something looks done.
  public func reviewLine(_ threads: [ChatSummary]) -> String? {
    let count = Self.looksDone(threads).count
    guard !selecting, count > 0 else { return nil }
    return count == 1 ? "1 chat looks done" : "\(count) chats look done"
  }

  /// The toolbar's title.
  public var toggleTitle: String { selecting ? "Cancel" : "Select" }

  /// Select needs a thread it could tick; Cancel always works.
  public func canToggle(_ threads: [ChatSummary]) -> Bool {
    selecting || !Self.live(threads).allSatisfy(\.pinned)
  }

  /// Select or Cancel: either way nothing is ticked, and nothing is archived. True when now selecting.
  @discardableResult
  public mutating func toggle() -> Bool {
    picked = []
    selecting.toggle()
    return selecting
  }

  /// Review: Select with what looks done ticked. Returns how many.
  @discardableResult
  public mutating func review(_ threads: [ChatSummary]) -> Int {
    picked = Set(Self.looksDone(threads).map(\.key))
    selecting = true
    return picked.count
  }

  /// A live row while selecting: the pinned thread has no tick (#598).
  public func shows(_ thread: ChatSummary) -> Bool { !selecting || !thread.pinned }

  /// The Done fold, while not selecting.
  public func showsDone(_ threads: [ChatSummary]) -> Bool { !selecting && !Self.done(threads).isEmpty }

  public func ticked(_ key: String) -> Bool { picked.contains(key) }

  public mutating func tick(_ key: String) {
    if picked.contains(key) { picked.remove(key) } else { picked.insert(key) }
  }

  /// What is ticked and still live: a refresh can finish or archive a ticked thread and take its row away.
  public func pickedLive(_ threads: [ChatSummary]) -> [String] { ChatWire.liveKeys(picked, in: threads) }

  public func archiveTitle(_ threads: [ChatSummary]) -> String { "Archive (\(pickedLive(threads).count))" }

  public func canArchive(_ threads: [ChatSummary]) -> Bool { !pickedLive(threads).isEmpty }

  /// *Archive (N)*: what goes, and Select ends.
  public mutating func archivePicked(_ threads: [ChatSummary]) -> [String] {
    let keys = pickedLive(threads)
    picked = []
    selecting = false
    return keys
  }
}
