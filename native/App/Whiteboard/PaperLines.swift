//  The paper under the ink: its lines, page ends, ghosts and margin marks. Moved from PaperBoard.swift as it was
//  (context-grabber-fz4x).

import ContextCore
import PaperKit
import UIKit

/// Paper under the ink: its colour, its grid or ruled lines, a faint line where each page ends, and the ghosts. In PaperKit's content view, so it moves with the board and is in nothing else.
final class PaperLines: UIView {
  private let shape = CAShapeLayer()
  /// The grid or ruled lines, under the page lines and the ghosts, as ink lies over all of this.
  private let rules = CAShapeLayer()
  /// A hair on screen, in board points: the lines stay that wide at any zoom.
  var hair: CGFloat = 1 {
    didSet {
      guard hair != oldValue else { return }
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      rules.lineWidth = hair
      CATransaction.commit()
    }
  }
  private var rulesAcross: [CGFloat] = []
  private var rulesSpan: ClosedRange<CGFloat> = 0...0
  private var rulesDown: [CGFloat] = []
  private var width: CGFloat = 0
  private var ends: [CGFloat] = []
  let ghostLayers = GhostLayers()
  /// Larry's controls (story 845), over the lines and under the ink, at their places on the board.
  private var overlays: [BoardOverlay] = []
  private var overlayViews: [String: UILabel] = [:]
  /// The margin's marks (stories 855, 861): the board's own, never Larry's, in no picture.
  struct Mark: Equatable {
    var id: String
    /// The row's middle, board points.
    var y: CGFloat
    var text: String
    var faint: Bool
    /// Where the words start, board points, for a mark beside the ink rather than in the margin (story 901).
    var x: CGFloat?
  }
  private var marks: [Mark] = []
  private var markViews: [String: UILabel] = [:]

  init(paper: UIColor) {
    super.init(frame: .zero)
    backgroundColor = paper
    isUserInteractionEnabled = false
    shape.fillColor = nil
    shape.strokeColor = UIColor(white: 0.5, alpha: 0.45).cgColor
    shape.lineWidth = 1
    rules.fillColor = nil
    rules.strokeColor = UIColor(white: 0.5, alpha: 0.3).cgColor
    layer.addSublayer(rules)
    layer.addSublayer(shape)
    layer.addSublayer(ghostLayers.holder)
  }

  required init?(coder: NSCoder) { nil }

  /// In board points.
  func show(width: CGFloat, ends: [CGFloat]) {
    self.width = width
    self.ends = ends
    setNeedsLayout()
  }

  /// In board points: lines over `span` at each of `across`, and side to side at each of `down`.
  func showRules(across: [CGFloat], span: ClosedRange<CGFloat>, down: [CGFloat]) {
    (rulesAcross, rulesSpan, rulesDown) = (across, span, down)
    setNeedsLayout()
  }

  /// Story 845: Larry's controls as they are now.
  func showMarks(_ list: [Mark]) {
    guard list != marks else { return }
    marks = list
    let ids = Set(list.map(\.id))
    for (id, view) in markViews where !ids.contains(id) {
      view.removeFromSuperview()
      markViews[id] = nil
    }
    for mark in list where markViews[mark.id] == nil {
      let label = UILabel()
      label.textAlignment = .center
      label.isAccessibilityElement = true
      label.accessibilityIdentifier = "whiteboard-margin-\(mark.id)"
      addSubview(label)
      markViews[mark.id] = label
    }
    for mark in list { if let label = markViews[mark.id] { lay(mark, label) } }
  }

  private func lay(_ mark: Mark, _ label: UILabel) {
    let scale = spot(of: CGPoint(x: 1, y: 0)).x - spot(of: .zero).x
    if let x = mark.x {
      // Story 901: the web board's grey 14-point words beside the folded header, read as the picture has them.
      let origin = spot(of: CGPoint(x: x, y: mark.y - 12))
      label.font = .systemFont(ofSize: BoardOutline.markerPoints * scale)
      label.textColor = UIColor(rgb: 0x999999)
      label.textAlignment = .left
      label.text = mark.text
      label.sizeToFit()
      label.frame.origin = origin
      label.frame.size.height = 24 * scale
      label.accessibilityLabel = "Lines folded"
      label.accessibilityValue = mark.text
      return
    }
    let size = CGSize(width: 44 * scale, height: 28 * scale)
    let center = spot(of: CGPoint(x: BoardMargin.width / 2, y: mark.y))
    label.frame = CGRect(
      x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
    label.font = .systemFont(ofSize: 17 * scale, weight: mark.faint ? .regular : .semibold)
    label.textColor = mark.faint ? .tertiaryLabel : .secondaryLabel
    label.text = mark.text
    label.accessibilityLabel =
      mark.faint ? "Looks like a header" : mark.text.hasPrefix("▸") ? "Folded header" : "Header"
    label.accessibilityValue = mark.text
  }

  func showOverlays(_ list: [BoardOverlay]) {
    overlays = list
    let ids = Set(list.map(\.id))
    for (id, view) in overlayViews where !ids.contains(id) {
      view.removeFromSuperview()
      overlayViews[id] = nil
    }
    for overlay in list where overlayViews[overlay.id] == nil {
      let label = UILabel()
      label.textAlignment = .center
      label.numberOfLines = 1
      label.clipsToBounds = true
      label.accessibilityIdentifier = "whiteboard-overlay-\(overlay.id)"
      addSubview(label)
      overlayViews[overlay.id] = label
    }
    setNeedsLayout()
  }

  /// A control's look: Larry's `fill` and `color` when he names them, else its kind's.
  private func lay(_ overlay: BoardOverlay, _ label: UILabel) {
    let origin = spot(of: overlay.rect.origin)
    let far = spot(of: CGPoint(x: overlay.rect.maxX, y: overlay.rect.maxY))
    label.frame = CGRect(x: origin.x, y: origin.y, width: far.x - origin.x, height: far.y - origin.y)
    let scale = width > 0 ? bounds.width / width : 1
    let larry = UIColor(rgb: WhiteboardTurn.larryColor)
    let (fill, text): (UIColor, UIColor) =
      switch overlay.kind {
      case .band: (larry.withAlphaComponent(0.12), larry)
      case .chip: (larry.withAlphaComponent(0.2), larry)
      case .button: (larry, .white)
      case .hint: (.clear, .secondaryLabel)
      }
    label.backgroundColor = overlay.styleColor("fill").map { UIColor(rgb: $0) } ?? fill
    label.textColor = overlay.styleColor("color").map { UIColor(rgb: $0) } ?? text
    label.font = .systemFont(ofSize: 15 * scale, weight: overlay.kind == .button ? .semibold : .regular)
    label.layer.cornerRadius = overlay.kind == .band ? 0 : min(label.frame.height / 2, 10 * scale)
    label.text = overlay.label
    label.accessibilityLabel = overlay.label
  }

  /// Column points to this view's own: PaperKit sizes it.
  func spot(of point: CGPoint) -> CGPoint {
    let scale = width > 0 ? bounds.width / width : 1
    return CGPoint(x: point.x * scale, y: point.y * scale)
  }

  /// This view's own point to the column's.
  func columnPoint(of spot: CGPoint) -> CGPoint {
    let scale = width > 0 ? bounds.width / width : 1
    return CGPoint(x: spot.x / scale, y: spot.y / scale)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    guard width > 0, bounds.width > 0 else { return }
    for overlay in overlays { if let label = overlayViews[overlay.id] { lay(overlay, label) } }
    for mark in marks { if let label = markViews[mark.id] { lay(mark, label) } }
    let path = CGMutablePath()
    for end in ends {
      let edge = spot(of: CGPoint(x: 0, y: end))
      path.move(to: edge)
      path.addLine(to: CGPoint(x: bounds.width, y: edge.y))
    }
    let ruled = CGMutablePath()
    for x in rulesAcross {
      ruled.move(to: spot(of: CGPoint(x: x, y: rulesSpan.lowerBound)))
      ruled.addLine(to: spot(of: CGPoint(x: x, y: rulesSpan.upperBound)))
    }
    for y in rulesDown {
      ruled.move(to: spot(of: CGPoint(x: 0, y: y)))
      ruled.addLine(to: spot(of: CGPoint(x: width, y: y)))
    }
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    shape.frame = bounds
    shape.path = path
    rules.frame = bounds
    rules.path = ruled
    ghostLayers.holder.setAffineTransform(CGAffineTransform(scaleX: bounds.width / width, y: bounds.width / width))
    CATransaction.commit()
  }
}
