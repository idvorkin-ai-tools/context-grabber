//  #405, stories 262–264: capture text with the keyboard's own dictation, or paste an image, without leaving
//  the Inbox. Add another saves locally and keeps this sheet ready for the next thought.

import BugKit
import ContextCore
import SwiftUI
import UIKit

struct InboxComposeView: View {
  @ObservedObject var inbox: InboxModel
  let logger: BugLogger
  @Environment(\.dismiss) private var dismiss
  @State private var draft = InboxDraft()
  @State private var preview: CGImage?
  @State private var hasImage = UIPasteboard.general.hasImages
  @State private var failure: String?
  @FocusState private var editing: Bool

  var body: some View {
    NavigationStack {
      Form {
        Section("Text or a note for the picture") {
          TextField("Something for Larry", text: $draft.text, axis: .vertical)
            .lineLimit(4...10)
            .focused($editing)
        }
        Section {
          if let preview {
            Image(decorative: preview, scale: 1).resizable().scaledToFit().frame(maxHeight: 160)
            Button("Remove image", role: .destructive) {
              draft.image = nil
              self.preview = nil
            }
          }
          Button("Paste image", action: pasteImage).disabled(!hasImage)
        }
        if let failure {
          Section {
            BugProblemView(
              problem: .grabber(
                failure, context: "InboxComposeView.add_or_paste",
                extra: [
                  "text_bytes": .number(Double(draft.text.utf8.count)),
                  "image_bytes": .number(Double(draft.image?.count ?? 0)), "store_available": .bool(inbox.store != nil),
                ]
              ), logger: logger)
          }
        }
        Section {
          Button("Add another") { add(another: true) }.disabled(!draft.canAdd)
        }
      }
      .navigationTitle("Add to Inbox")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Add") { add(another: false) }.disabled(!draft.canAdd)
        }
      }
      .onAppear { editing = true }
      .onReceive(NotificationCenter.default.publisher(for: UIPasteboard.changedNotification)) { _ in
        hasImage = UIPasteboard.general.hasImages
      }
      .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
        hasImage = UIPasteboard.general.hasImages
      }
    }
  }

  private func pasteImage() {
    guard let data = UIPasteboard.general.image?.pngData(), let picture = InboxSend.thumbnail(data) else {
      failure = "The clipboard image could not be read. Copy the image again and try Paste image."
      hasImage = UIPasteboard.general.hasImages
      return
    }
    draft.image = data
    preview = picture
    failure = nil
  }

  private func add(another: Bool) {
    do {
      try inbox.add(&draft, another: another)
      preview = nil
      failure = nil
      if another { editing = true } else { dismiss() }
    } catch {
      failure = "The item could not be added: \(error.localizedDescription)"
    }
  }
}
