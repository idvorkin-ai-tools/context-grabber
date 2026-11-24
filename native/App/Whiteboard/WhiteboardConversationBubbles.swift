//  The board's open conversation as chat bubbles (#1384, story 1277; spec 2026-11-12-whiteboard-conversation-design.md,
//  *The conversation as chat*): Igor's on the right in the accent colour, Larry's on the left, links as chips and
//  tables as grids through Chat's own bubble text. The same size and scrolling as the panel's lines (stories 837, 887).

import ContextCore
import SwiftUI
import UIKit

/// The panel's switch between Lines and Bubbles, remembered for the next board.
struct WhiteboardPanelLookSwitch: View {
  @Binding var look: WhiteboardPanelLook

  var body: some View {
    Picker("Conversation look", selection: $look) {
      ForEach(WhiteboardPanelLook.allCases, id: \.self) { look in
        Text(look.title).tag(look)
      }
    }
    .pickerStyle(.segmented)
    .fixedSize()
    .font(.footnote)
    .accessibilityIdentifier("whiteboard-conversation-look")
  }
}

/// The thread's recent end as bubbles, at most `maxHeight` tall; past that it scrolls, newest at the bottom.
struct WhiteboardConversationBubbles: View {
  let bubbles: [WhiteboardPanelLook.Bubble]
  let maxHeight: CGFloat
  let chat: ChatModel
  let thread: String
  @State private var position = ScrollPosition(edge: .bottom)
  /// Story 887: a new bubble brings the newest into view only while Igor is at the bottom.
  @State private var following = true
  @State private var contentHeight: CGFloat = 0

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 6) {
        ForEach(bubbles) { bubble in
          WhiteboardConversationBubble(bubble: bubble, chat: chat, thread: thread)
            .id(bubble.id)
        }
      }
      .onGeometryChange(for: CGFloat.self) {
        $0.size.height
      } action: {
        contentHeight = $0
      }
      // Inside the content, so the scroll view is among its ancestors.
      .background(FingersOnlyScroll())
    }
    .scrollPosition($position)
    .defaultScrollAnchor(.bottom)
    .onScrollGeometryChange(for: Bool.self) { geometry in
      let end = geometry.contentSize.height - geometry.containerSize.height + geometry.contentInsets.bottom
      return WhiteboardNote.followsNewest(offset: Double(geometry.contentOffset.y), end: Double(max(end, 0)))
    } action: { _, atBottom in
      following = atBottom
    }
    .onChange(of: bubbles.map(\.id)) { _, _ in
      if following { position.scrollTo(edge: .bottom) }
    }
    .frame(height: min(max(contentHeight, 1), maxHeight))
    .accessibilityElement(children: .contain)
    .accessibilityLabel(WhiteboardNote.panelPlace(following: following))
    .accessibilityIdentifier("whiteboard-conversation-bubbles")
  }
}

/// One bubble: Chat's colours and its bubble text, without Chat's hold menu (that is Chat's, through *Open in Chat*).
private struct WhiteboardConversationBubble: View {
  let bubble: WhiteboardPanelLook.Bubble
  let chat: ChatModel
  let thread: String

  var body: some View {
    HStack {
      if bubble.mine { Spacer(minLength: 48) }
      Group {
        if bubble.quiet {
          Text(bubble.text).italic().foregroundStyle(Color(WhiteboardNoteInk.quiet))
        } else {
          BubbleText(text: bubble.text, chat: chat, thread: thread)
            .foregroundStyle(bubble.mine ? Color.white : Color.primary)
            .tint(bubble.mine ? .white : .accentColor)
        }
      }
      .font(.footnote)
      .padding(.horizontal, 10).padding(.vertical, 6)
      .background(
        bubble.mine ? Color.accentColor : Color(.secondarySystemBackground),
        in: RoundedRectangle(cornerRadius: 14)
      )
      .contextMenu {
        Button("Copy", systemImage: "doc.on.doc") { UIPasteboard.general.string = bubble.text }
      }
      if !bubble.mine { Spacer(minLength: 48) }
    }
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier(bubble.mine ? "whiteboard-bubble-mine" : "whiteboard-bubble-larry")
  }
}

/// The spec's *the Pencil never acts on it*: the scroll view this sits in takes finger touches only, as the lines'
/// text view does (`WhiteboardConversationText`).
private struct FingersOnlyScroll: UIViewRepresentable {
  func makeUIView(context: Context) -> UIView {
    let view = UIView()
    view.isUserInteractionEnabled = false
    return view
  }

  func updateUIView(_ view: UIView, context: Context) {
    // The scroll view is the background's ancestor only once it is in the window.
    DispatchQueue.main.async {
      var next = view.superview
      while let current = next, !(current is UIScrollView) { next = current.superview }
      guard let scroll = next as? UIScrollView else { return }
      let fingers = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
      for gesture in scroll.gestureRecognizers ?? [] where gesture.allowedTouchTypes != fingers {
        gesture.allowedTouchTypes = fingers
      }
    }
  }
}
