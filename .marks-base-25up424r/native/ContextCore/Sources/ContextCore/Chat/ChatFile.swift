//  #633, stories 480–494: a PDF or any document attached to a chat message. What the picker hands over is read here,
//  whole, so a file that can never go is said at the pick; a picture goes the way a pasted one does.

import Foundation

#if canImport(UniformTypeIdentifiers)
  import UniformTypeIdentifiers
#endif

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

    /// For the session log: which problem, with the file's type and never its name, which stays in the copyable problem.
    public var logFields: [String: Any] {
      switch self {
      case .tooBig(let name, let bytes, let limit):
        return ["problem": "too_big", "file_type": ChatFile.type(of: name), "bytes": bytes, "limit": limit]
      case .empty(let name):
        return ["problem": "empty", "file_type": ChatFile.type(of: name)]
      case .unreadable(let name, _):
        return ["problem": "unreadable", "file_type": ChatFile.type(of: name)]
      }
    }
  }

  /// What the picker chose, read in full. The size is judged before a byte is read. ponytail: a picture over the cap
  /// is refused here too, though a pasted one is shrunk on sending; read it first if photos from Files ever hit this.
  public static func read(_ url: URL, maxBytes: Int = maxBytes) throws -> Picked {
    let name = url.lastPathComponent
    #if canImport(Darwin)
      let scoped = url.startAccessingSecurityScopedResource()
      defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    #endif
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
    #if canImport(UniformTypeIdentifiers)
      // The type too, not the bytes alone: ImageIO can read a PDF, which must stay a document.
      if UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true,
        InboxSend.thumbnail(data, maxPixels: 1) != nil
      {
        return .image(data)
      }
    #endif
    // Linux (just test-linux) reads no image, so a picture goes as a document there; the Mac tests the picture.
    return .file(ChatFile(name: name, data: data))
  }

  /// What the log says a file is: the name's extension, never the name.
  public static func type(of name: String) -> String { (name as NSString).pathExtension.lowercased() }

  /// In binary units, as the cap is: 10 MiB reads 10 MB rather than a decimal 10.5 MB.
  static func size(_ bytes: Int) -> String {
    ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .binary)
  }

  /// What the upload says it is; the Cockpit goes by the bytes.
  static func mime(name: String) -> String {
    #if canImport(UniformTypeIdentifiers)
      UTType(filenameExtension: (name as NSString).pathExtension)?.preferredMIMEType ?? "application/octet-stream"
    #else
      linuxMIME[(name as NSString).pathExtension.lowercased()] ?? "application/octet-stream"
    #endif
  }

  #if !canImport(UniformTypeIdentifiers)
    /// Linux only (just test-linux): no type database there, so the common types as UTType names them on Apple.
    /// `testTheUploadNamesItsTypeAsApplesTypesDo` holds both to the same answers. ponytail: an extension missing here
    /// goes as bytes on Linux only; add it with a line in that test.
    static let linuxMIME: [String: String] = [
      "pdf": "application/pdf", "png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg", "gif": "image/gif",
      "txt": "text/plain", "json": "application/json", "zip": "application/zip", "html": "text/html",
      "csv": "text/csv",
    ]
  #endif
}
