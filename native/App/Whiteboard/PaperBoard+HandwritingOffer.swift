//  A board on paper: the system's offer to convert handwriting is put away as soon as it shows, and a tapped group whose
//  selection went with it is selected again (stories 945, 946; bead context-grabber-4nnh). iPadOS has no switch for
//  the offer: on the iPad it came up over a tapped group a second after the tap, and the selection went with no callback.

import ContextCore
import PaperKit
import UIKit

/// What the watch remembers between looks: the tap it is holding, its tries, and the offers it put away.
@MainActor
final class HandwritingOfferWatch {
  var tapUntil: Double?
  var tapSeen: Double = 0
  var putBacks = 0
  var gaveUp = false
  var offers = 0
  var lastOffer: Double?
}

extension PaperBoardController {
  /// Every tenth of a second while the board's controller lives: the offer put away, and a tapped group held.
  func watchHandwritingOffers() {
    guard model.editable else { return }
    let watch = HandwritingOfferWatch()
    Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(0.1))
        guard let self else { return }
        self.putAwayHandwritingOffer(watch)
        self.holdTappedGroup(watch)
      }
    }
  }

  /// Story 945: the system's handwriting popover over the paper, dismissed with whatever it presented.
  private func putAwayHandwritingOffer(_ watch: HandwritingOfferWatch) {
    guard let root = view.window?.rootViewController else { return }
    var chain: [UIViewController] = []
    var next = root.presentedViewController
    while let shown = next {
      chain.append(shown)
      next = shown.presentedViewController
    }
    guard
      let offer = chain.first(where: { shown in
        !shown.isBeingDismissed
          && PaperProbe.isHandwritingOffer(
            popover: shown.modalPresentationStyle == .popover,
            pointsAtPaper: shown.popoverPresentationController?.sourceView?.isDescendant(of: paper.view) == true,
            remote: shown.isViewLoaded && BoardCoverWatch.drawnElsewhere(shown.view),
            kind: Self.kind(shown))
      })
    else { return }
    // The lowest of the system's own controllers in the chain, so what it presented goes with it; never the board.
    let index = chain.firstIndex(where: { $0 === offer }) ?? 0
    let first = chain[..<index].lastIndex(where: { !Self.kind($0).contains("Campo") }).map { $0 + 1 } ?? 0
    let bottom = chain[min(first, index)]
    guard let presenter = bottom.presentingViewController, presenter.presentedViewController === bottom else { return }
    let selected = paper.selection.count
    let handwriting = handwritingTools()
    let now = CACurrentMediaTime()
    watch.offers += 1
    watch.lastOffer = now
    let sinceTap = watch.tapUntil != nil ? Int((now - watch.tapSeen) * 1_000) : -1
    presenter.dismiss(animated: false)
    var event: [String: Any] = [
      "action": "handwriting_offer", "board": model.board.id, "kinds": chain[min(first, index)...].map(Self.kind),
      "source_rect": offer.popoverPresentationController.map { popover in
        popover.sourceView.map { rect($0.convert(popover.sourceRect, to: nil)) } ?? []
      } ?? [],
      "paper_first": paper.isFirstResponder, "handwriting": handwriting, "selected": selected,
      "group_tap": groupTap != nil, "ms_since_tap": sinceTap, "n": watch.offers, "put_away": true,
    ]
    guard watch.offers <= 50 else { return }
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(0.15))
      guard let self else { return }
      event["selected_after"] = self.paper.selection.count
      var shown = self.view.window?.rootViewController?.presentedViewController
      var over: [String] = []
      while let next = shown {
        if !next.isBeingDismissed, next !== self.view.window?.rootViewController?.presentedViewController {
          over.append(Self.kind(next))
        }
        shown = next.presentedViewController
      }
      event["over_board_after"] = over
      self.log.event("whiteboard", event)
    }
  }

  /// Story 946: a tapped group's selection gone with no touch since is put back, up to three times.
  private func holdTappedGroup(_ watch: HandwritingOfferWatch) {
    guard let tap = groupTap, let markup = paper.markup else { return }
    let now = CACurrentMediaTime()
    if watch.tapUntil != tap.until {
      watch.tapUntil = tap.until
      watch.tapSeen = now
      watch.putBacks = 0
      watch.gaveUp = false
      if LaunchHooks.current.whiteboard.fakeHandwritingOffer { fakeHandwritingOffer(until: tap.until) }
    }
    guard paper.selection.isEmpty else { return }
    let undo = paper.undoManager
    let wanted = groupElements(tap.names, in: markup)
    let verdict = PaperProbe.groupTapLoss(
      selected: paper.selection.count, wanted: wanted.count, same: paper.selection == wanted, live: now < tap.until,
      undoing: undo?.isUndoing == true || undo?.isRedoing == true, putBacks: watch.putBacks)
    guard verdict == .putBack || (verdict == .givenUp && !watch.gaveUp) else { return }
    if verdict == .givenUp { watch.gaveUp = true }
    if verdict == .putBack { watch.putBacks += 1 }
    log.event(
      "whiteboard",
      [
        "action": "group_tap_lost", "board": model.board.id, "verdict": verdict.rawValue, "try": watch.putBacks,
        "ms_since_tap": Int((now - watch.tapSeen) * 1_000), "strokes": wanted.count,
        "offer_ms_ago": watch.lastOffer.map { Int((now - $0) * 1_000) } ?? -1, "handwriting": handwritingTools(),
        "paper_first": paper.isFirstResponder,
      ])
    guard verdict == .putBack else { return }
    reselectGroupTap(until: tap.until, why: "lost")
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(0.15))
      guard let self else { return }
      self.log.event(
        "whiteboard",
        [
          "action": "group_tap_lost_after", "board": self.model.board.id, "try": watch.putBacks,
          "selected": self.paper.selection.count, "held": self.paper.selection == wanted,
        ])
    }
  }

  /// The simulator's stand-in for the iPad's offer (`GRABBER_WHITEBOARD_FAKE_OFFER`): a popover at the paper named as
  /// the system's is, shown a beat after the tap, which empties the selection without a callback as the iPad did.
  private func fakeHandwritingOffer(until: Double) {
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(0.6))
      guard let self, self.groupTap?.until == until, let presenter = self.view.window?.rootViewController else {
        return
      }
      var top = presenter
      while let shown = top.presentedViewController { top = shown }
      let fake = FakeCampoOfferController()
      fake.modalPresentationStyle = .popover
      fake.popoverPresentationController?.sourceView = self.paper.view
      fake.popoverPresentationController?.sourceRect = CGRect(x: 40, y: 40, width: 200, height: 60)
      top.present(fake, animated: false)
      // Silently, as on the iPad: no selection callback, which would put the group back by the older path.
      let delegate = self.paper.delegate
      self.paper.delegate = nil
      self.paper.selection = []
      self.paper.delegate = delegate
    }
  }

  private static func kind(_ controller: UIViewController) -> String { String(describing: type(of: controller)) }
}

/// The fake offer's controller: "Campo" in its name, as the iPad's `_UICampoPresentedViewController`.
final class FakeCampoOfferController: UIViewController {
  override func viewDidLoad() {
    super.viewDidLoad()
    let label = UILabel()
    label.text = "Convert to text?"
    label.accessibilityIdentifier = "whiteboard-fake-handwriting-offer"
    label.frame = CGRect(x: 12, y: 12, width: 180, height: 30)
    view.addSubview(label)
    preferredContentSize = CGSize(width: 200, height: 54)
  }
}
