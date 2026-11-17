//  The board's open conversation panel's thread text (story 837, #917): it shows the newest line.

import UIKit

/// Story 837 (#917): the panel's thread, scrolled to its newest line once it is laid out (a scroll asked for before then,
/// as the panel opens, went nowhere), and kept there as the panel settles, until a finger scrolls it.
final class NewestInView: UITextView {
  private var toEnd = true

  func showNewest() {
    toEnd = true
    setNeedsLayout()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    if isDragging || isDecelerating { toEnd = false }
    guard toEnd, bounds.height > 0 else { return }
    let end = max(-adjustedContentInset.top, contentSize.height - bounds.height + adjustedContentInset.bottom)
    if abs(contentOffset.y - end) > 0.5 { contentOffset.y = end }
  }
}
