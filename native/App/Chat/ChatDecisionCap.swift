//  A long card at the top of its thread (spec 2026-11-14-chat-decision-cards-design.md, *A long card at the top of its
//  thread*; story 1135, bead context-grabber-97s): under its heading, the card scrolls inside a bounded height instead
//  of growing past the screen. Its own file, so the card's own file grows by one wrapper.

import SwiftUI

/// The card under its heading: as tall as it is while that fits under `cap`, then `cap` tall with its own scroll.
/// No cap (on *Decisions*, on the board's popup, or before the thread is measured): drawn as it is.
struct ChatDecisionCappedBody<Content: View>: View {
  let cap: CGFloat?
  @ViewBuilder let content: () -> Content
  @State private var height: CGFloat = 0

  var body: some View {
    if let cap {
      ScrollView {
        content()
          .frame(maxWidth: .infinity, alignment: .leading)
          .onGeometryChange(for: CGFloat.self) {
            $0.size.height
          } action: {
            height = $0
          }
      }
      .scrollBounceBehavior(.basedOnSize)
      .frame(height: height > 0 ? min(height, cap) : nil)
      .frame(maxHeight: cap)
      .accessibilityIdentifier("decision-card-body")
    } else {
      content()
    }
  }
}
