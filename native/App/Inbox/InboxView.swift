//  #305, stories 038 and 039: the Inbox, newest first: what each item is, its note, the link's site, when it was
//  shared, and whether it has reached Larry. A swipe deletes one; a refused item shows the Cockpit's reason, copyable.

import BugKit
import ContextCore
import SwiftUI

struct InboxView: View {
  @ObservedObject var inbox: InboxModel
  let logger: BugLogger

  var body: some View {
    List {
      if inbox.store == nil {
        BugProblemView(
          problem: .grabber(
            "This build has no App Group, so nothing shared can reach the Inbox.", context: "InboxView.load", extra: [:]
          ), logger: logger)
      } else if inbox.items.isEmpty {
        Text("Nothing shared yet. In any app's share sheet, pick Grabber Native.").foregroundStyle(.secondary)
      }
      ForEach(inbox.items) { item in
        InboxRow(item: item, thumbnail: inbox.thumbnails[item.id], logger: logger)
          .swipeActions { Button("Delete", role: .destructive) { inbox.delete(item) } }
      }
    }
    .navigationTitle("Inbox")
    .accessibilityIdentifier("inbox-list")
  }
}

private struct InboxRow: View {
  let item: InboxItem
  let thumbnail: CGImage?
  let logger: BugLogger

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(alignment: .top) {
        if let picture = thumbnail {
          Image(decorative: picture, scale: 1).resizable().scaledToFill().frame(width: 56, height: 56).clipped()
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        VStack(alignment: .leading, spacing: 2) {
          Text(title).font(.body).lineLimit(3)
          if let note = item.note { Text(note).font(.subheadline).foregroundStyle(.secondary) }
          Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
      }
      if let reason = item.refused {
        BugProblemView(
          problem: .grabber(
            "Larry's inbox refused it: \(reason)", context: "InboxView.send",
            extra: ["item": .string(item.id), "kind": .string(item.kind.rawValue)]), logger: logger)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("inbox-item-\(item.status)")
  }

  private var title: String {
    switch item.kind {
    case .link: return item.text ?? item.url ?? "A link"
    case .text: return item.text ?? ""
    case .image: return "A picture"
    }
  }

  private var subtitle: String {
    let when = Date(timeIntervalSince1970: Double(item.sharedAt) / 1000).formatted(date: .abbreviated, time: .shortened)
    let place = item.site.map { "\($0) · " } ?? ""
    switch item.status {
    case .waiting: return "\(place)\(when) · waiting to send"
    case .refused: return "\(place)\(when)"
    case .sent:
      let sent = Date(timeIntervalSince1970: Double(item.sentAt ?? 0) / 1000).formatted(
        date: .omitted, time: .shortened)
      return "\(place)\(when) · sent to Larry at \(sent)"
    }
  }
}
