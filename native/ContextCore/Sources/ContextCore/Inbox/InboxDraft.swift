//  #405, stories 262–264: one compose draft becomes a text item or an image with a note. Only a successful save
//  clears it, so Add another starts fresh and a failed write keeps the thought.

import Foundation

public struct InboxDraft: Equatable, Sendable {
  public var text = ""
  /// A pasted image, encoded as PNG by the app.
  public var image: Data?

  public init() {}

  private var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
  public var canAdd: Bool { !trimmedText.isEmpty || image?.isEmpty == false }
  public var byteCount: Int { trimmedText.utf8.count + (image?.count ?? 0) }

  public enum Problem: LocalizedError {
    case empty
    public var errorDescription: String? { "Add some text or paste an image first." }
  }

  @discardableResult
  public mutating func save(to store: InboxStore, at sharedAt: Int64) throws -> InboxItem {
    guard canAdd else { throw Problem.empty }
    let hasImage = image?.isEmpty == false
    let item = InboxItem(
      kind: hasImage ? .image : .text, sharedAt: sharedAt,
      text: hasImage ? nil : trimmedText, note: hasImage ? trimmedText : nil)
    let saved = try store.add(item, image: hasImage ? image : nil, imageExtension: "png")
    self = InboxDraft()
    return saved
  }
}
