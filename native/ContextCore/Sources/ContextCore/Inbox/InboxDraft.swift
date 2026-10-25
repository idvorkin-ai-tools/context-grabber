//  #405, stories 262–264: one compose draft becomes a text item or an image with a note. Only a successful save
//  clears it, so Add another starts fresh and a failed write keeps the thought.

import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct InboxDraft: Equatable, Sendable {
  public var text = ""
  /// A pasted image, its bytes as copied; the file extension follows what they are.
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
  public mutating func save(
    to store: InboxStore, at sharedAt: Int64, id: String = UUID().uuidString.lowercased(), thread: String? = nil
  ) throws -> InboxItem {
    guard canAdd else { throw Problem.empty }
    let picture = image?.isEmpty == false ? image : nil
    let item = InboxItem(
      id: id, kind: picture != nil ? .image : .text, sharedAt: sharedAt,
      text: picture != nil ? nil : trimmedText, note: picture != nil ? trimmedText : nil, thread: thread)
    let saved = try store.add(item, image: picture, imageExtension: picture.map(Self.fileExtension(of:)) ?? "jpg")
    self = InboxDraft()
    return saved
  }

  static func fileExtension(of image: Data) -> String {
    CGImageSourceCreateWithData(image as CFData, nil).flatMap(CGImageSourceGetType)
      .flatMap { UTType($0 as String)?.preferredFilenameExtension } ?? "jpg"
  }
}
