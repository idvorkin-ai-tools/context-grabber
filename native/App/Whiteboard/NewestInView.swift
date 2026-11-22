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

  /// Story 1127: a copy holding a link chip carries the link's full address where the chip was, not its words.
  override func copy(_ sender: Any?) {
    let range = selectedRange
    guard range.length > 0, let text = attributedText else { return super.copy(sender) }
    let picked = text.attributedSubstring(from: range)
    var out = ""
    var lastURL: URL?
    picked.enumerateAttribute(.link, in: NSRange(location: 0, length: picked.length)) { value, run, _ in
      if let url = value as? URL {
        if url != lastURL { out += url.absoluteString }
        lastURL = url
      } else {
        out += picked.attributedSubstring(from: run).string.replacingOccurrences(of: "\u{FFFC}", with: "")
        lastURL = nil
      }
    }
    UIPasteboard.general.string = out
  }
}
