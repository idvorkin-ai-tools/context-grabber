//  The board's conversation strip, apart from the drawing screen (#1039): the note's one line over the paper (story
//  766), the problem under it with Larry's Retry and Dismiss (stories 761, 762, 775, 776), the conversation it opens
//  above the paper on an iPad (stories 768, 837, 1045, 1047, 1048) and the thread's text that scrolls inside it. What
//  they say is ContextCore's `WhiteboardNote` and `WhiteboardLarryWait` (host-tested); these views lay it out from the
//  values they are handed and give taps back through the actions they are handed.

import BugKit
import ContextCore
import SwiftUI
import UIKit

/// The bar's note, one line (story 766): Larry's state first so it is never what gets cut off (story 667), the newest
/// thing said, how many suggestions show, and a chevron. A finger tap opens the conversation over the board, or on an
/// iPhone the board's thread in Chat (story 769). VoiceOver reads his state in words when it reaches the note, not on
/// every tick. The line's room stays when it has nothing to say, so the paper never moves for it.
struct WhiteboardNoteStrip: View {
  /// What the strip shows at a moment, all read then, as the line ticks: Larry's clock (story 667).
  struct Shown {
    let line: WhiteboardNote.Line?
    /// What a tap on the line does.
    let tap: WhiteboardNote.Tap
    let conversationOpen: Bool
    /// Story 895: every mark of Larry's kept at once; nil when there is none, or the board is only looked at.
    let keepAll: (() -> Void)?
    /// Story 777: Larry has the picture and twenty seconds have passed; nil otherwise.
    let interrupt: (() -> Void)?
  }

  let shown: (ContinuousClock.Instant) -> Shown
  /// Whether the line ticks once a second: Larry's clock, or a message holding the middle (story 766).
  let ticks: Bool
  let onPhone: Bool
  let tapNote: () -> Void
  @ScaledMetric(relativeTo: .footnote) private var noteHeight: CGFloat = 28

  var body: some View {
    if ticks {
      TimelineView(.periodic(from: .now, by: 1)) { _ in content(now: .now) }
    } else {
      content(now: .now)
    }
  }

  @ViewBuilder private func content(now: ContinuousClock.Instant) -> some View {
    let shown = shown(now)
    let (tap, conversationOpen) = (shown.tap, shown.conversationOpen)
    if let line = shown.line {
      HStack(spacing: 6) {
        if let state = line.state {
          Text(state).lineLimit(1).layoutPriority(1)
            .accessibilityLabel(line.spokenState ?? state)
            .accessibilityIdentifier("whiteboard-note-state")
          if line.middle != nil { Text("·") }
        }
        if let middle = line.middle {
          Text(middle).lineLimit(1).truncationMode(line.keepsEnd ? .head : .tail)
            // Story 1053 (#1003): Larry's words lead.
            .foregroundStyle(line.larrySpeaks ? Color.primary : Color(WhiteboardNoteInk.quiet))
            .accessibilityIdentifier("whiteboard-note-said")
        }
        Spacer(minLength: 0)
        if let keep = line.keep { Text(keep).lineLimit(1).fixedSize() }
        if let keepAll = shown.keepAll {
          Button("Keep all", action: keepAll).buttonStyle(.borderless).fixedSize()
            .accessibilityHint("Keeps every mark of Larry's, top to bottom, clear of your writing")
            .accessibilityIdentifier("whiteboard-keep-all")
        }
        if let interrupt = shown.interrupt {
          Button("Interrupt", action: interrupt).buttonStyle(.borderless).fixedSize()
            .accessibilityHint("Stops waiting for Larry's answer, so the next picture is a fresh ask")
            .accessibilityIdentifier("whiteboard-larry-interrupt")
        }
        if tap != .nothing {
          Button(action: tapNote) {
            Image(systemName: onPhone ? "chevron.right" : conversationOpen ? "chevron.up" : "chevron.down")
          }
          .buttonStyle(.borderless)
          .accessibilityLabel(
            onPhone ? "Open in Chat" : conversationOpen ? "Hide the conversation" : "Show the conversation"
          )
          .accessibilityIdentifier("whiteboard-note-chevron")
        }
      }
      .font(.footnote).foregroundStyle(Color(WhiteboardNoteInk.quiet))
      .padding(.vertical, 4).padding(.horizontal)
      .frame(minHeight: noteHeight)
      .contentShape(Rectangle())
      .onTapGesture(perform: tapNote)
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("whiteboard-note")
    } else {
      // Nothing to say yet: the line's room stays, so the paper doesn't jump when it first speaks.
      Color.clear.frame(height: noteHeight).accessibilityHidden(true)
    }
  }
}

/// The board's problem under the note, copyable, with what each of Larry's own problems offers: his silence a Dismiss
/// (stories 761, 762), a picture the Cockpit hasn't taken in twenty seconds Retry and Dismiss (stories 775, 776).
struct WhiteboardProblemRow: View {
  let problem: BugProblem
  let logger: BugLogger
  let dismissSilence: () -> Void
  let retryLarry: () -> Void
  let dismissStuck: () -> Void

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      BugProblemView(problem: problem, logger: logger)
      // Stories 761, 762: his silence stays until he next answers or this.
      if problem.context == WhiteboardLarryClock.DidntAnswer.context {
        Spacer()
        Button("Dismiss", action: dismissSilence).font(.footnote).buttonStyle(.borderless)
          .accessibilityIdentifier("whiteboard-dismiss-problem")
      }
      // Stories 775, 776: a picture the Cockpit hasn't taken in twenty seconds.
      if problem.context == WhiteboardLarryWait.stuckContext {
        Spacer()
        Button("Retry", action: retryLarry).font(.footnote).buttonStyle(.borderless)
          .accessibilityIdentifier("whiteboard-larry-retry")
        Button("Dismiss", action: dismissStuck).font(.footnote).buttonStyle(.borderless)
          .accessibilityIdentifier("whiteboard-larry-dismiss")
      }
    }
    .padding(.horizontal)
  }
}

/// Story 768: the open note, above the board (story 1048): the board's thread, selectable, then the status chip and
/// what the mic hears, and *Open in Chat*. The Pencil never acts on it: the thread's text takes finger touches only,
/// and the rest holds nothing to scroll or draw on. Its text stops at about seventy characters (story 1045), and its
/// thread at a fifth of the page, past which it scrolls rather than grows (story 837).
struct WhiteboardConversationPanel: View {
  /// The thread's recent end.
  let rows: [WhiteboardNote.Row]
  /// Whether the live rows tick once a second, with Larry's clock.
  let ticks: Bool
  /// The status chip and what the mic hears, at a moment (story 1047).
  let live: (ContinuousClock.Instant) -> [WhiteboardNote.Row]
  /// The whole page's height, not the paper's it pushes down, so opening it doesn't change its own limit (story 837).
  let pageHeight: CGFloat
  /// Opens the board's thread in Chat; nil when the board has none yet.
  let openInChat: (() -> Void)?
  /// Story 1045 (#1003): the conversation's text stops at about seventy characters of its own type.
  @ScaledMetric(relativeTo: .footnote) private var readableWidth: CGFloat = 470
  /// Story 837: what the panel's chip, Open in Chat and padding take, and the fewest lines of thread it keeps.
  @ScaledMetric(relativeTo: .footnote) private var panelChrome: CGFloat = 72
  @ScaledMetric(relativeTo: .footnote) private var threadFloor: CGFloat = 64

  private var threadCap: CGFloat {
    let page = pageHeight > 0 ? WhiteboardNote.panelHeight(board: Double(pageHeight)) : WhiteboardNote.panelFloor
    return max(CGFloat(page) - panelChrome, threadFloor)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      WhiteboardConversationText(rows: rows, maxHeight: threadCap)
      if ticks {
        TimelineView(.periodic(from: .now, by: 1)) { _ in liveRows(now: .now) }
      } else {
        liveRows(now: .now)
      }
      if let openInChat {
        Button("Open in Chat", action: openInChat)
          .font(.footnote).buttonStyle(.borderless)
          .accessibilityIdentifier("whiteboard-conversation-chat")
      }
    }
    .frame(maxWidth: readableWidth, alignment: .leading)
    .padding(.horizontal).padding(.vertical, 6)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.regularMaterial)
    .contentShape(Rectangle())
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("whiteboard-conversation")
  }

  /// Under the thread: the status chip (story 1047) and what the mic is hearing.
  private func liveRows(now: ContinuousClock.Instant) -> some View {
    // One column of its own: a TimelineView lays several children over each other (#882).
    VStack(alignment: .leading, spacing: 4) {
      ForEach(live(now)) { row in
        Group {
          if row.id == "live-chip" {
            Text("\(Text(row.who).bold()) · \(row.text)")
              .padding(.horizontal, 10).padding(.vertical, 3)
              .background(Color(WhiteboardNoteInk.quiet).opacity(0.12), in: Capsule())
          } else {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
              Text("\(row.who):").bold()
              Text(row.text)
            }
          }
        }
        .font(.footnote).foregroundStyle(Color(WhiteboardNoteInk.quiet))
        .textSelection(.enabled)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("whiteboard-conversation-\(row.id)")
      }
    }
  }
}

/// #1003 (story 1053): the note's and the panel's quieter text, at least 4.5:1 on the paper and the panel's material in
/// either appearance; the system's secondary and tertiary greys measured about 3:1 and 2:1. Larry's words take the main
/// text colour.
enum WhiteboardNoteInk {
  static let quiet = UIColor { traits in
    traits.userInterfaceStyle == .dark ? UIColor(white: 0.72, alpha: 1) : UIColor(white: 0.36, alpha: 1)
  }
}

/// Story 768: the board's thread in the open note, one text that can be selected and copied across rows and scrolls
/// inside the panel, newest at the bottom. A UITextView rather than SwiftUI text: its gestures can be told to take
/// fingers only, so the Pencil neither scrolls nor selects it, and a ticking clock beside it doesn't reset a selection.
struct WhiteboardConversationText: UIViewRepresentable {
  let rows: [WhiteboardNote.Row]
  let maxHeight: CGFloat

  func makeUIView(context: Context) -> NewestInView {
    let view = NewestInView()
    view.isEditable = false
    view.isSelectable = true
    view.backgroundColor = .clear
    view.textContainerInset = .zero
    view.textContainer.lineFragmentPadding = 0
    view.adjustsFontForContentSizeCategory = true
    view.accessibilityIdentifier = "whiteboard-conversation-text"
    return view
  }

  func updateUIView(_ view: NewestInView, context: Context) {
    let text = Self.text(rows)
    fingersOnly(view)
    guard view.attributedText != text else { return }
    view.attributedText = text
    view.showNewest()
  }

  func sizeThatFits(_ proposal: ProposedViewSize, uiView: NewestInView, context: Context) -> CGSize? {
    let width = proposal.width ?? 320
    let fit = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    return CGSize(width: width, height: min(fit.height, maxHeight, proposal.height ?? .infinity))
  }

  /// ponytail: every gesture the text view has now, set again on each update since UIKit adds some lazily; a Pencil
  /// touch on it then does nothing at all. If one ever slips through, subclass UITextView and filter in its
  /// `gestureRecognizerShouldBegin`.
  private func fingersOnly(_ view: UITextView) {
    let fingers = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
    for gesture in view.gestureRecognizers ?? [] where gesture.allowedTouchTypes != fingers {
      gesture.allowedTouchTypes = fingers
    }
  }

  private static func text(_ rows: [WhiteboardNote.Row]) -> NSAttributedString {
    let body = UIFont.preferredFont(forTextStyle: .footnote)
    let bold = UIFont(
      descriptor: body.fontDescriptor.withSymbolicTraits(.traitBold) ?? body.fontDescriptor, size: body.pointSize)
    let text = NSMutableAttributedString()
    for (index, row) in rows.enumerated() {
      if index > 0 { text.append(NSAttributedString(string: "\n")) }
      // Story 1053 (#1003): Larry's words lead; Igor's are quieter, still 4.5:1.
      let color: UIColor = row.kind == .larry ? .label : WhiteboardNoteInk.quiet
      text.append(NSAttributedString(string: "\(row.who): ", attributes: [.font: bold, .foregroundColor: color]))
      text.append(NSAttributedString(string: row.text, attributes: [.font: body, .foregroundColor: color]))
    }
    return text
  }
}
