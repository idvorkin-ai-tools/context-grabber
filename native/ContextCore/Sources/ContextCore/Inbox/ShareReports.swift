import Foundation

/// Stories 155 and 157 (#876): the share extension's own problem reports and session log, in the App Group, where the
/// app takes them into its reports and sends them on through iCloud. The extension has no reporter of its own.
public enum ShareReports {
  /// The folder's name in the group: the extension's alone, since a take moves its index aside.
  public static let folderName = "BugKit-share"

  /// The folder inside a group container.
  public static func folder(in container: URL) -> URL {
    container.appendingPathComponent(folderName, isDirectory: true)
  }

  /// The App Group's folder, or nil where there is no share extension (a Mac) or no group (a test host, Linux).
  public static func folder(group: String = InboxStore.appGroup) -> URL? {
    #if targetEnvironment(macCatalyst) || !canImport(Darwin)
      return nil
    #else
      return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group).map(folder(in:))
    #endif
  }
}
