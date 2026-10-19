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
        textSection
        imageSection
        failureSection
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

  private var textSection: some View {
    Section("Text or a note for the picture") {
      TextField("Something for Larry", text: $draft.text, axis: .vertical)
        .lineLimit(4...10)
        .focused($editing)
    }
  }

  private var imageSection: some View {
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
  }

  @ViewBuilder
  private var failureSection: some View {
    if let failure {
      Section {
        failureView(failure)
      }
    }
  }

  private func failureView(_ message: String) -> some View {
    let textBytes = draft.text.utf8.count
    let imageBytes = draft.image?.count ?? 0
    let problem = BugProblem.grabber(
      message, context: "InboxComposeView.add_or_paste",
      extra: [
        "text_bytes": .int(textBytes),
        "image_bytes": .int(imageBytes),
        "store_available": .bool(inbox.store != nil),
      ])
    return BugProblemView(problem: problem, logger: logger)
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
