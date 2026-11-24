//  Story 1608 (#1362): while a thread's first read is on its way, it says so instead of showing a blank page. A read
//  can take as long as its timeout, and a Cockpit slow to answer left the thread empty that long.

public enum ChatThreadLoading {
  public static let words = "Loading this chat…"

  /// - Parameters:
  ///   - thread: the screen is a thread the Cockpit holds (false for a new chat from the +, which has nothing to read)
  ///   - read: its messages were read at least once since the app opened
  ///   - pending: Igor's own messages for it still waiting to go
  ///   - problem: a problem, the Cockpit-down banner among them, shows on the thread
  ///   - offline: the device has no network, which keeps its own line
  public static func shows(thread: Bool, read: Bool, pending: Int, problem: Bool, offline: Bool) -> Bool {
    thread && !read && pending == 0 && !problem && !offline
  }
}
