//  The board's open conversation panel's thread text (story 837, #917): it shows the newest line.

import ContextCore
import UIKit

/// Story 837 (#917): the panel's thread, scrolled to its newest line once it is laid out (a scroll asked for before then,
/// as the panel opens, went nowhere), and kept there as the panel settles and new lines come. Bead
/// context-grabber-97s (story 887): a finger that scrolls it up to read stops it following, so a new line leaves it
/// where it is; a finger that brings it back to the bottom starts it following again.
final class NewestInView: UITextView {
  /// Whether a new line brings the newest into view: true while at the bottom, false once scrolled up to read.
  private(set) var following = true {
    didSet { if following != oldValue { accessibilityLabel = WhiteboardNote.panelPlace(following: following) } }
  }

  private var end: CGFloat {
    max(-adjustedContentInset.top, contentSize.height - bounds.height + adjustedContentInset.bottom)
  }

  override init(frame: CGRect, textContainer: NSTextContainer?) {
    super.init(frame: frame, textContainer: textContainer)
    accessibilityLabel = WhiteboardNote.panelPlace(following: true)
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    accessibilityLabel = WhiteboardNote.panelPlace(following: true)
  }

  /// New text: shown at the newest if it was following, else left where Igor scrolled it (`offset`, from before).
  func show(_ text: NSAttributedString) {
    let offset = contentOffset
    attributedText = text
    if following {
      setNeedsLayout()
      return
    }
    layoutIfNeeded()
    contentOffset.y = min(max(offset.y, -adjustedContentInset.top), end)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    guard bounds.height > 0 else { return }
    // A finger moved it: it follows from the bottom, and only from there.
    if isTracking || isDragging || isDecelerating {
      following = WhiteboardNote.followsNewest(offset: Double(contentOffset.y), end: Double(end))
      return
    }
    guard following else { return }
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
