//  #305, story 038: Grabber Native in any app's share sheet. A small card previews what is shared (a link, text or
//  one image), takes an optional note, and *Add to Inbox* writes it to the Inbox in the App Group and closes at once.
//  No network here: the app sends it to Larry later (story 039).

import ContextCore
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The App Group the app reads the Inbox from (the app's and the widgets' entitlement too).
private let group = "group.com.idvorkin.grabbernative"

final class ShareViewController: UIViewController {
  private let shared = Shared()

  override func viewDidLoad() {
    super.viewDidLoad()
    let card = UIHostingController(
      rootView: ShareCard(
        shared: shared, add: { [weak self] note in self?.add(note: note) ?? "closed" },
        cancel: { [weak self] in self?.close(cancelled: true) }))
    addChild(card)
    card.view.frame = view.bounds
    card.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.addSubview(card.view)
    card.didMove(toParent: self)
    Task { await shared.load(extensionContext?.inputItems as? [NSExtensionItem] ?? []) }
  }

  /// Nil when kept; otherwise why not, for the card to show.
  private func add(note: String) -> String? {
    guard let store = InboxStore.shared(group: group) else {
      return "This build has no App Group, so the Inbox is unreachable."
    }
    guard let item = shared.item(note: note) else { return shared.problem ?? "Nothing to add yet." }
    do {
      try store.add(item, image: shared.image, imageExtension: shared.imageExtension)
    } catch {
      return "The Inbox could not be written: \(error.localizedDescription)"
    }
    close(cancelled: false)
    return nil
  }

  private func close(cancelled: Bool) {
    if cancelled {
      extensionContext?.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
    } else {
      extensionContext?.completeRequest(returningItems: nil)
    }
  }
}

/// What the share sheet handed over, read once: a web link first, then an image, then text.
@MainActor
final class Shared: ObservableObject {
  @Published private(set) var url: URL?
  @Published private(set) var text: String?
  @Published private(set) var image: Data?
  @Published private(set) var problem: String?
  @Published private(set) var loaded = false
  private(set) var imageExtension = "jpg"

  func load(_ items: [NSExtensionItem]) async {
    defer { loaded = true }
    let providers = items.flatMap { $0.attachments ?? [] }
    if let p = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }),
      let found = try? await p.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL, !found.isFileURL
    {
      url = found
      text = items.first?.attributedContentText?.string.nilIfEmpty
      return
    }
    if let p = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }) {
      let type =
        p.registeredTypeIdentifiers.compactMap(UTType.init).first { $0.conforms(to: .image) } ?? .jpeg
      if let data = await Self.data(p, type: type) {
        image = data
        imageExtension = type.preferredFilenameExtension ?? "jpg"
        return
      }
    }
    if let p = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }),
      let found = try? await p.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String
    {
      // A link shared as text (some apps do) is still a link.
      if let link = URL(string: found.trimmingCharacters(in: .whitespacesAndNewlines)),
        ["http", "https"].contains(link.scheme ?? "")
      {
        url = link
      } else {
        text = found
      }
      return
    }
    problem = "Grabber Native takes a link, some text or one image."
  }

  func item(note: String) -> InboxItem? {
    let now = Int64(Date().timeIntervalSince1970 * 1000)
    let note = note.trimmingCharacters(in: .whitespacesAndNewlines)
    if let url { return InboxItem(kind: .link, sharedAt: now, url: url.absoluteString, text: text, note: note) }
    if image != nil { return InboxItem(kind: .image, sharedAt: now, note: note) }
    if let text { return InboxItem(kind: .text, sharedAt: now, text: text, note: note) }
    return nil
  }

  private static func data(_ provider: NSItemProvider, type: UTType) async -> Data? {
    await withCheckedContinuation { done in
      _ = provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, _ in done.resume(returning: data)
      }
    }
  }
}

struct ShareCard: View {
  @ObservedObject var shared: Shared
  let add: (String) -> String?
  let cancel: () -> Void
  @State private var note = ""
  @State private var failure: String?

  var body: some View {
    NavigationStack {
      Form {
        Section { preview }
        Section("Note") {
          TextField("Optional", text: $note, axis: .vertical).lineLimit(1...4)
        }
        if let failure {
          // ponytail: no BugKit in the extension, so the copyable error is a selectable line and a Copy button;
          // link BugKit here if the extension grows.
          Section {
            Text(failure).textSelection(.enabled)
            Button("Copy") { UIPasteboard.general.string = "ShareCard.add: \(failure)" }
          }
        }
      }
      .navigationTitle("Grabber Native")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: cancel) }
        ToolbarItem(placement: .confirmationAction) {
          Button("Add to Inbox") { failure = add(note) }.disabled(!shared.loaded || shared.problem != nil)
        }
      }
    }
  }

  @ViewBuilder private var preview: some View {
    if !shared.loaded {
      ProgressView()
    } else if let url = shared.url {
      VStack(alignment: .leading, spacing: 4) {
        if let title = shared.text { Text(title).font(.headline).lineLimit(2) }
        Text(url.host ?? url.absoluteString).font(.subheadline)
        Text(url.absoluteString).font(.caption).foregroundStyle(.secondary).lineLimit(2)
      }
    } else if let data = shared.image, let picture = InboxSend.thumbnail(data) {
      Image(decorative: picture, scale: 1).resizable().scaledToFit().frame(maxHeight: 220)
    } else if let text = shared.text {
      Text(text).lineLimit(4)
    } else {
      Text(shared.problem ?? "Nothing to share.").foregroundStyle(.secondary)
    }
  }
}

extension String {
  fileprivate var nilIfEmpty: String? { isEmpty ? nil : self }
}
