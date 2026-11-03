//  #633, stories 455–459: a PDF or any document attached to a chat message. What the picker hands over is read here,
//  whole, so a file that can never go is said at the pick; a picture goes the way a pasted one does.

import Foundation
import UniformTypeIdentifiers

public struct ChatFile: Equatable, Sendable {
  /// The Cockpit's cap on an attachment.
  public static let maxBytes = InboxSend.maxImageBytes

  public let name: String
  public let data: Data

  public init(name: String, data: Data) {
    self.name = name
    self.data = data
  }

  public var size: String { Self.size(data.count) }

  public enum Picked: Equatable, Sendable {
    case image(Data)
    case file(ChatFile)
  }

  public enum Problem: LocalizedError, Equatable {
    case tooBig(name: String, bytes: Int, limit: Int)
    case empty(name: String)
    case unreadable(name: String, reason: String)

    public var errorDescription: String? {
      switch self {
      case .tooBig(let name, let bytes, let limit):
        return "\(name) is \(ChatFile.size(bytes)), over the \(ChatFile.size(limit)) the Cockpit takes, so it can't go."
      case .empty(let name):
        return "\(name) is empty, so there is nothing to send."
      case .unreadable(let name, let reason):
        return "\(name) could not be read: \(reason)"
      }
    }
  }

  /// What the picker chose, read in full. The size is judged before a byte is read. ponytail: a picture over the cap
  /// is refused here too, though a pasted one is shrunk on sending; read it first if photos from Files ever hit this.
  public static func read(_ url: URL, maxBytes: Int = maxBytes) throws -> Picked {
    let name = url.lastPathComponent
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    if let bytes = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, bytes > maxBytes {
      throw Problem.tooBig(name: name, bytes: bytes, limit: maxBytes)
    }
    let data: Data
    do {
      data = try Data(contentsOf: url)
    } catch {
      throw Problem.unreadable(name: name, reason: error.localizedDescription)
    }
    guard !data.isEmpty else { throw Problem.empty(name: name) }
    guard data.count <= maxBytes else { throw Problem.tooBig(name: name, bytes: data.count, limit: maxBytes) }
    // The type too, not the bytes alone: ImageIO can read a PDF, which must stay a document.
    if UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true,
      InboxSend.thumbnail(data, maxPixels: 1) != nil
    {
      return .image(data)
    }
    return .file(ChatFile(name: name, data: data))
  }

  static func size(_ bytes: Int) -> String { ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file) }

  /// What the upload says it is; the Cockpit goes by the bytes.
  static func mime(name: String) -> String {
    UTType(filenameExtension: (name as NSString).pathExtension)?.preferredMIMEType ?? "application/octet-stream"
  }
}
