//  #305, story 038: Grabber Native in any app's share sheet. A small card previews what is shared (a link, text or
//  one image), takes an optional message (#673), and *Start a chat* (chat, spec 2026-10-25) writes it to the Inbox in the App Group and closes at once.
//  The app sends it to Larry later (story 039). The one question asked of the network here is which recent chats to
//  offer beside *New chat* (#587, stories 495–499), and nothing waits for its answer. The message's mic button is
//  BugKit's NoteDictation, the problem report's (#793, story 546). Apple's guidance keeps an app extension off the
//  microphone; whether iOS lets this one listen is the phone's to answer, and a refusal is a copyable line.

import AVFAudio
import BugKit
import ContextCore
import Speech
import SwiftUI
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
  private let shared = Shared()
  private let recent = RecentChats()
  // ponytail: the extension keeps no session log, so the dictation's events go nowhere and a failure's evidence is
  // the copied problem (its state and both permissions); give it a log in the App Group if that is not enough.
  private let dictation = NoteDictation(logger: { _, _ in })

  override func viewDidLoad() {
    super.viewDidLoad()
    let card = UIHostingController(
      rootView: ShareCard(
        shared: shared,
        recent: recent,
        dictation: dictation,
        add: { [weak self] note, thread in
          guard let self else { return nil }
          return self.add(note: note, thread: thread)
        },
        cancel: { [weak self] in self?.close(cancelled: true) }))
    addChild(card)
    card.view.frame = view.bounds
    card.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.addSubview(card.view)
    card.didMove(toParent: self)
    Task { await shared.load(extensionContext?.inputItems as? [NSExtensionItem] ?? []) }
    Task { await recent.load() }
  }

  /// The host taking the card away, however it does: SwiftUI's onDisappear is not proven to fire then.
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    dictation.stop(why: "closed")
  }

  /// Nil when kept; otherwise why not, for the card to show.
  private func add(note: String, thread: String?) -> String? {
    guard let store = InboxStore.shared(cockpit: ChatCockpit.address(override: nil)) else {
      return "This build has no App Group, so the Inbox is unreachable."
    }
    guard var item = shared.item(note: note) else { return shared.problem ?? "Nothing to add yet." }
    item.thread = thread
    item.offered = ShareThreads.offered(recent.read)
    do {
      try store.add(item, image: shared.image, imageExtension: shared.imageExtension)
    } catch {
      return "The Inbox could not be written: \(error.localizedDescription)"
    }
    close(cancelled: false)
    return nil
  }

  private func close(cancelled: Bool) {
    // Sent or cancelled mid-recording: the message took the words so far, and nothing more is wanted (story 546).
    dictation.stop(why: cancelled ? "cancel" : "sent")
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
  /// The image's preview, decoded once.
  @Published private(set) var preview: CGImage?
  @Published private(set) var problem: String?
  /// What the share offered and what failed, carried by a copied problem (Codex on #387).
  private(set) var problemState = ""
  @Published private(set) var loaded = false
  private(set) var imageExtension = "jpg"
  /// The types the other app offered, for the log (#673): it settles what a share really hands over.
  private var offeredTypes = ""

  func load(_ items: [NSExtensionItem]) async {
    defer { loaded = true }
    let providers = items.flatMap { $0.attachments ?? [] }
    let offered = providers.flatMap(\.registeredTypeIdentifiers).joined(separator: ", ")
    offeredTypes = offered
    if let found = await ShareLink.find(in: providers, markedUp: { await Self.text($0).0 }) {
      url = found
      text = items.first?.attributedContentText?.string.nilIfEmpty
      return
    }
    if let p = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }) {
      let type =
        p.registeredTypeIdentifiers.compactMap(UTType.init).first { $0.conforms(to: .image) } ?? .jpeg
      let (data, error) = await Self.data(p, type: type)
      if let data {
        image = data
        preview = InboxSend.thumbnail(data)
        imageExtension = type.preferredFilenameExtension ?? "jpg"
      } else {
        fail("The picture could not be read.", state: "type: \(type.identifier); error: \(error ?? "none")", offered)
      }
      return
    }
    // Any text, as the share sheet's rule offers it: plain, or marked up (RTF, HTML) and turned plain (Codex on #387).
    if let p = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.text.identifier) }) {
      let (found, state) = await Self.text(p)
      guard let found, !found.isEmpty else { return fail("The shared text could not be read.", state: state, offered) }
      text = found
      return
    }
    fail("Grabber Native takes a link, some text or one image.", state: "nothing it reads", offered)
  }

  private func fail(_ message: String, state: String, _ offered: String) {
    problem = message
    problemState = "\(state); offered: \(offered.isEmpty ? "nothing" : offered)"
  }

  func item(note: String) -> InboxItem? {
    let now = Int64(Date().timeIntervalSince1970 * 1000)
    let note = note.trimmingCharacters(in: .whitespacesAndNewlines)
    var item: InboxItem
    if let url {
      item = InboxItem(kind: .link, sharedAt: now, url: url.absoluteString, text: text, note: note)
    } else if image != nil {
      item = InboxItem(kind: .image, sharedAt: now, note: note)
    } else if let text {
      item = InboxItem(kind: .text, sharedAt: now, text: text, note: note)
    } else {
      return nil
    }
    item.shareTypes = offeredTypes
    return item
  }

  private static func data(_ provider: NSItemProvider, type: UTType) async -> (Data?, String?) {
    await withCheckedContinuation { done in
      _ = provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, error in
        done.resume(returning: (data, error.map { "\($0)" }))
      }
    }
  }

  /// Plain text as it is; RTF and HTML through NSAttributedString; any other text type as UTF-8. The state says
  /// which type was read and what failed, for a copied problem.
  private static func text(_ provider: NSItemProvider) async -> (String?, String) {
    if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
      let plain = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String
    {
      return (plain, "type: public.plain-text")
    }
    let type =
      provider.registeredTypeIdentifiers.compactMap(UTType.init).first { $0.conforms(to: .text) } ?? .plainText
    let (data, error) = await data(provider, type: type)
    guard let data else { return (nil, "type: \(type.identifier); error: \(error ?? "none")") }
    let kind: NSAttributedString.DocumentType? =
      type.conforms(to: .rtf) ? .rtf : type.conforms(to: .html) ? .html : nil
    if let kind {
      let read = try? NSAttributedString(data: data, options: [.documentType: kind], documentAttributes: nil)
      return (read?.string, "type: \(type.identifier)")
    }
    return (String(data: data, encoding: .utf8), "type: \(type.identifier)")
  }
}

/// The chats the card offers beside *New chat*, asked of the Cockpit once as it opens; nil until it answers.
@MainActor
final class RecentChats: ObservableObject {
  @Published private(set) var read: ShareThreads.Read?

  func load() async {
    // An extension gets no launch hooks, so a simulator's card never has an address (#525).
    read = await ShareThreads.read(cockpit: ChatCockpit.address(override: nil)) {
      try await URLSession.shared.data(for: $0)
    }
  }
}

struct ShareCard: View {
  @ObservedObject var shared: Shared
  @ObservedObject var recent: RecentChats
  @ObservedObject var dictation: NoteDictation
  let add: (String, String?) -> String?
  let cancel: () -> Void
  /// What he writes on the card: it lands as a chat message (#673), kept as the item's note.
  @State private var message = ""
  /// The chat ticked; nil is *New chat*. Only a tap changes it, never the list arriving (story 499).
  @State private var thread: String?
  @State private var failure: String?
  @State private var added = false

  var body: some View {
    NavigationStack {
      Form {
        Section { preview }
        Section("Message") {
          HStack(alignment: .top) {
            // Off while it listens: each partial result rewrites the field from the note at the tap, typing and all.
            TextField("Optional", text: $message, axis: .vertical).lineLimit(1...4).accessibilityLabel("Message")
              .disabled(dictation.listening || dictation.processing)
            micButton
          }
          if dictation.starting || dictation.processing {
            Text(dictation.starting ? "Starting voice input…" : "Finishing voice input…")
              .font(.caption).foregroundStyle(.secondary)
          }
          if let voiceProblem { BugProblemView(problem: voiceProblem) }
        }
        destinations
        if let problem = shared.problem {
          Section {
            Text(problem).textSelection(.enabled)
            Text(shared.problemState).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            Button("Copy") {
              UIPasteboard.general.string = "ShareCard.load: \(problem)\n\(shared.problemState)"
            }
          }
        }
        if let failure {
          // ponytail: the card's older errors keep their selectable line and Copy button; BugKit is linked now (#793),
          // so they can become BugProblemViews in a change of their own.
          Section {
            Text(failure).textSelection(.enabled)
            Button("Copy") { UIPasteboard.general.string = "ShareCard.add: \(failure)" }
          }
        }
      }
      // A swipe down closes the card without Cancel.
      .onDisappear { dictation.stop(why: "closed") }
      .navigationTitle("Grabber Native")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: cancel) }
        ToolbarItem(placement: .confirmationAction) {
          Button(thread == nil ? "Start a chat" : "Send") {
            failure = add(message, thread)
            added = failure == nil
          }
          .disabled(!shared.loaded || shared.problem != nil || added)
        }
      }
    }
  }

  /// The problem report's mic button (BugKit's BugReportSheet), on the message: a tap dictates after what is typed.
  private var micButton: some View {
    Button {
      let field = $message
      dictation.toggle(note: message) { field.wrappedValue = $0 }
    } label: {
      Image(systemName: dictation.listening ? "stop.circle.fill" : "mic.circle.fill")
        .font(.title)
        .symbolEffect(.pulse, isActive: dictation.listening)
        .foregroundStyle(dictation.listening ? Color.red : Color.accentColor)
    }
    // Borderless, or the Form gives the whole row to the button and a tap in the field starts dictation.
    .buttonStyle(.borderless)
    .disabled(dictation.starting || dictation.processing)
    .accessibilityLabel(dictation.listening ? "Stop dictating" : "Speak the message")
    .accessibilityIdentifier("share-mic")
  }

  /// What stopped the dictation, copyable, with what the phone says of both permissions: the evidence for whether an
  /// extension may listen at all (#793).
  private var voiceProblem: BugProblem? {
    guard let message = dictation.problem else { return nil }
    var extra = dictation.problemState
    extra["mic_permission"] =
      switch AVAudioApplication.shared.recordPermission {
      case .granted: "granted"
      case .denied: "denied"
      case .undetermined: "undetermined"
      @unknown default: "unknown"
      }
    extra["speech_permission"] =
      switch SFSpeechRecognizer.authorizationStatus() {
      case .authorized: "authorized"
      case .denied: "denied"
      case .restricted: "restricted"
      case .notDetermined: "undetermined"
      @unknown default: "unknown"
      }
    // BugAppInfo.buildLine's shape, "1.2 (34) abc1234"; GitSha is the app's key, in this extension's Info.plist too.
    let info = { Bundle.main.object(forInfoDictionaryKey: $0) as? String ?? "unknown" }
    return BugProblem(
      message: message, context: "ShareCard.dictation",
      build: "\(info("CFBundleShortVersionString")) (\(info("CFBundleVersion"))) \(info("GitSha"))", extra: extra)
  }

  private var destinations: some View {
    Section("Send to") {
      destination("New chat", age: nil, key: nil)
      switch recent.read {
      case nil:
        ProgressView().accessibilityLabel("Reading your recent chats")
      case .threads(let rows):
        ForEach(rows) { destination($0.title, age: $0.lastAt, key: $0.key) }
      case .problem(let why):
        // The card's copyable idiom, as below; the list being out of reach is normal, so it stays small.
        VStack(alignment: .leading, spacing: 4) {
          Text(why).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
          Button("Copy") { UIPasteboard.general.string = "ShareCard.recentChats: \(why)" }.font(.caption)
        }
      }
    }
  }

  private func destination(_ title: String, age: Date?, key: String?) -> some View {
    Button {
      thread = key
    } label: {
      HStack {
        Text(title).lineLimit(1).foregroundStyle(.primary)
        Spacer()
        if let age {
          Text(age, format: .relative(presentation: .numeric, unitsStyle: .abbreviated))
            .font(.caption).foregroundStyle(.secondary)
        }
        if thread == key { Image(systemName: "checkmark").foregroundStyle(.tint) }
      }
    }
    .accessibilityAddTraits(thread == key ? .isSelected : [])
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
    } else if let picture = shared.preview {
      Image(decorative: picture, scale: 1).resizable().scaledToFit().frame(maxHeight: 220)
    } else if let text = shared.text {
      Text(text).lineLimit(4)
    } else if shared.problem == nil {
      Text("Nothing to share.").foregroundStyle(.secondary)
    }
  }
}

extension String {
  fileprivate var nilIfEmpty: String? { isEmpty ? nil : self }
}
