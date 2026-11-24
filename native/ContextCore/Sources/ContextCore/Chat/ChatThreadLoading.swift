//  Story 1608 (#1362): while a thread's first read is on its way, it says so instead of showing a blank page. A read
//  can take as long as its timeout, and a Cockpit slow to answer left the thread empty that long.

public enum ChatThreadLoading {
  public static let words = "Loading this chat…"

  /// - Parameters:
  ///   - read: its messages were read at least once since the app opened
  ///   - pending: Igor's own messages for it still waiting to go
  ///   - problem: a problem, the Cockpit-down banner among them, shows on the thread
  ///   - offline: the device has no network, which keeps its own line
  public static func shows(read: Bool, pending: Int, problem: Bool, offline: Bool) -> Bool {
    !read && pending == 0 && !problem && !offline
  }
}
