//  A Cockpit thread link in a chat bubble (spec 2026-10-25-native-chat-design.md, Links in a thread: A Cockpit thread
//  link opens here; story 744): https://<Cockpit host>/#thread/<key>, an Inbox ask being a thread too, opens that
//  thread in the app when the list knows it; otherwise the link goes where any link goes.

import Foundation

public enum ChatCockpitLink {
  /// Where a tapped link goes instead of out of the app.
  public enum Jump: Equatable, Sendable {
    /// The thread already on screen: nothing to open.
    case here
    case thread(String)
  }

  /// The thread key a Cockpit link names, or nil when it is not one.
  public static func threadKey(_ url: URL) -> String? {
    guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
      url.host?.lowercased() == CockpitPage.host, url.port == nil || url.port == 443,
      url.path.isEmpty || url.path == "/",
      let fragment = url.fragment.map({ $0.removingPercentEncoding ?? $0 }), fragment.hasPrefix("thread/")
    else { return nil }
    let key = String(fragment.dropFirst("thread/".count))
    guard !key.isEmpty, !key.contains("/"), !key.contains(where: \.isWhitespace) else { return nil }
    return key
  }

  /// A tap on `url` in thread `current`: that thread opened in the app, nothing for this one, or nil to open the link
  /// as today (not a Cockpit thread link, or a thread the list does not know).
  public static func jump(_ url: URL, from current: String?, known: Set<String>) -> Jump? {
    guard let key = threadKey(url) else { return nil }
    if key == current { return .here }
    return known.contains(key) ? .thread(key) : nil
  }
}
