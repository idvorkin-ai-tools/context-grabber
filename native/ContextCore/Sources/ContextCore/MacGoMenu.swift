//  Stories 726, 730 and 734-735 (#722, #783, #745): which of the Mac's Go menu items, and New Chat, stay live while
//  another screen covers home.

import Foundation

public enum MacGoMenu {
  /// The report opens over whatever is in front and closes nothing, so it stays live on every screen (#783). Every
  /// other destination would replace the screen in front (a live timer or call among them), so it waits for home.
  public static func live(_ rowID: String, homeInFront: Bool) -> Bool {
    homeInFront || rowID == reportRow
  }

  /// New Chat (Control+N, #745): from home, from chat in front of home, or with chat in a window of its own, which it
  /// brings forward; anything else in front of home would have to close, so it waits.
  public static func newChatLive(homeInFront: Bool, chatInFront: Bool, chatHasWindow: Bool) -> Bool {
    homeInFront || chatInFront || chatHasWindow
  }

  /// Home's *Report a problem* tile.
  public static let reportRow = "report_problem"
}
