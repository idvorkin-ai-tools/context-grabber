//  Stories 726 and 730 (#722, #783): which of the Mac's Go menu items stay live while another screen covers home.

import Foundation

public enum MacGoMenu {
  /// The report opens over whatever is in front and closes nothing, so it stays live on every screen (#783). Every
  /// other destination would replace the screen in front (a live timer or call among them), so it waits for home.
  public static func live(_ rowID: String, homeInFront: Bool) -> Bool {
    homeInFront || rowID == reportRow
  }

  /// Home's *Report a problem* tile.
  public static let reportRow = "report_problem"
}
