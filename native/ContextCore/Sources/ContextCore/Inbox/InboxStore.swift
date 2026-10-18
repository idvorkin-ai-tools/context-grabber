//  #305, stories 038 and 039: the Inbox, things shared to Grabber Native waiting for Larry (spec
//  2026-10-17-native-share-inbox-design.md; plan 2026-10-18-share-inbox-plan.md). One file per item in a directory
//  of the App Group, because the share extension and the app are two processes: the extension only adds, and the
//  app records sends and deletes.

import Foundation

public struct InboxItem: Codable, Equatable, Sendable, Identifiable {
  public enum Kind: String, Codable, Sendable { case link, text, image }

  /// A lowercase UUID: the Cockpit's idempotency key (`[A-Za-z0-9_-]{1,64}`).
  public let id: String
  public let kind: Kind
  /// Unix ms.
  public let sharedAt: Int64
  public var url: String?
  public var text: String?
  public var note: String?
  /// The image's file name beside the item, as shared (HEIC stays HEIC until it is sent).
  public var imageFile: String?
  /// Unix ms when the Cockpit took it.
  public var sentAt: Int64?
  /// The Cockpit's reason when it said the item itself is wrong; such an item is never sent again.
  public var refused: String?

  public enum Status: Equatable, Sendable { case waiting, sent, refused }

  public var status: Status { sentAt != nil ? .sent : refused != nil ? .refused : .waiting }

  /// A simulator fixture's id (the `GRABBER_INBOX_FIXTURE` hook): such an item is never sent to Larry.
  public static func fixtureID() -> String { "fixture-" + UUID().uuidString.lowercased() }
  public var isFixture: Bool { id.hasPrefix("fixture-") }

  /// A link's site, the only "where it came from" iOS gives a share extension.
  public var site: String? { url.flatMap { URL(string: $0)?.host } }

  public init(
    id: String = UUID().uuidString.lowercased(), kind: Kind, sharedAt: Int64, url: String? = nil,
    text: String? = nil, note: String? = nil, imageFile: String? = nil
  ) {
    self.id = id
    self.kind = kind
    self.sharedAt = sharedAt
    self.url = url
    self.text = text
    self.note = note?.isEmpty == true ? nil : note
    self.imageFile = imageFile
  }

  enum CodingKeys: String, CodingKey {
    case id, kind, url, text, note, refused
    case sharedAt = "shared_at"
    case imageFile = "image_file"
    case sentAt = "sent_at"
  }
}

public struct InboxStore: Sendable {
  public let directory: URL

  public init(directory: URL) {
    self.directory = directory
  }

  /// The App Group's Inbox, or nil without the group (a test host, a build without the entitlement).
  public static func shared(group: String) -> InboxStore? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
      .map { InboxStore(directory: $0.appendingPathComponent("Inbox", isDirectory: true)) }
  }

  /// The image first, the item last, so an item on disk always has its image.
  @discardableResult
  public func add(_ item: InboxItem, image: Data? = nil, imageExtension: String = "jpg") throws -> InboxItem {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var item = item
    if let image {
      let name = "\(item.id).\(imageExtension)"
      try image.write(to: directory.appendingPathComponent(name), options: .atomic)
      item.imageFile = name
    }
    try write(item)
    return item
  }

  /// Newest first. An item that does not decode is skipped and named in `unreadable`.
  public func items() -> (items: [InboxItem], unreadable: [String]) {
    let files =
      (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
    var items: [InboxItem] = []
    var unreadable: [String] = []
    for file in files where file.pathExtension == "json" {
      if let data = try? Data(contentsOf: file), let item = try? JSONDecoder().decode(InboxItem.self, from: data) {
        items.append(item)
      } else {
        unreadable.append(file.lastPathComponent)
      }
    }
    return (items.sorted { ($0.sharedAt, $0.id) > ($1.sharedAt, $1.id) }, unreadable.sorted())
  }

  /// What still goes to Larry, oldest first.
  public func waiting() -> [InboxItem] { items().items.filter { $0.status == .waiting }.reversed() }

  public var waitingCount: Int { items().items.filter { $0.status == .waiting }.count }

  public func image(of item: InboxItem) -> Data? {
    item.imageFile.flatMap { try? Data(contentsOf: directory.appendingPathComponent($0)) }
  }

  public func markSent(_ id: String, at: Int64) throws {
    try update(id) { $0.sentAt = at }
  }

  public func markRefused(_ id: String, reason: String) throws {
    try update(id) { $0.refused = reason }
  }

  public func delete(_ item: InboxItem) throws {
    if let image = item.imageFile {
      try? FileManager.default.removeItem(at: directory.appendingPathComponent(image))
    }
    try FileManager.default.removeItem(at: file(item.id))
  }

  private func update(_ id: String, _ change: (inout InboxItem) -> Void) throws {
    var item = try JSONDecoder().decode(InboxItem.self, from: Data(contentsOf: file(id)))
    change(&item)
    try write(item)
  }

  private func write(_ item: InboxItem) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    try encoder.encode(item).write(to: file(item.id), options: .atomic)
  }

  private func file(_ id: String) -> URL { directory.appendingPathComponent("\(id).json") }
}
